class eayuncenter
{
  # for /etc/eayuncenter/eayuncenter.conf
  $nodes_hash         = $::fuel_settings['nodes']
  $mysql_db_name      = $::fuel_settings['eayuncenter']['mysql_db']
  $mysql_username     = $::fuel_settings['eayuncenter']['mysql_username']
  $mysql_password     = $::fuel_settings['eayuncenter']['mysql_password']
  $mysql_url          = "${::fuel_settings['management_vip']}:3306/$mysql_db_name"
  $mongo_db_name      = $::fuel_settings['eayuncenter']['mongo_db']
  $mongo_db_user      = $::fuel_settings['eayuncenter']['mongo_username']
  $mongo_password     = $::fuel_settings['eayuncenter']['mongo_password']
  $mongo_url          = eayuncenter_mongo_url($nodes_hash)
  $ceilometer_db_name = "ceilometer"
  $ceilometer_db_user = "ceilometer"
  $ceilometer_db_pwd  = $::fuel_settings['ceilometer']['db_password']
  $java_opts          = $::fuel_settings['eayuncenter']['java_opts']
  $logback_method     = "FILE"

  # for docker
  $docker_image_name     = "eayuncenter"
  $docker_image_version  = "latest"
  $docker_container_name = "eayuncenter"

  # for mysql & mongo db initialization
  $auth_url            = "http://${::fuel_settings['management_vip']}:5000/v2.0/"
  $auth_username       = $::fuel_settings['access']['user']
  $auth_password       = $::fuel_settings['access']['password']
  $auth_tenant         = $::fuel_settings['access']['tenant']
  $admin_tenant_id     = get_tenant_id($auth_url, $auth_username, $auth_password, $auth_tenant)
  $management_vip      = $::fuel_settings['management_vip']
  $primary_mongo_nodes = filter_nodes($::fuel_settings['nodes'], 'role', 'primary-mongo')
  $primary_mongo_ip    = $primary_mongo_nodes[0]['internal_address']
  $mongo_db_password   = $::fuel_settings['ceilometer']['db_password']
  $db_tmp_dir          = '/var/tmp/eayuncenter'
  $datacenter_id       = $::fuel_settings['eayuncenter']['datacenter_id']

  # for haproxy
  # by default, listen only on public VIP
  $public              = true
  $internal            = false
  $public_virtual_ip   = $::fuel_settings['public_vip']
  $internal_virtual_ip = $::fuel_settings['internal_vip']
  if $public and $internal {
    $virtual_ips = [$public_virtual_ip, $internal_virtual_ip]
  } elsif $internal {
    $virtual_ips = [$internal_virtual_ip]
  } elsif $public {
    $virtual_ips = [$public_virtual_ip]
  }

  $ha_mode = $::fuel_settings['deployment_mode'] ? { /^(ha|ha_compact)$/  => true, default => false}

  $roles = node_roles($::fuel_settings['nodes'], $::fuel_settings['uid'])
  $is_primary_controller = member($roles, 'primary-controller')

  include eayuncenter::stages

  if ($ha_mode and $is_primary_controller) or (! $ha_mode) {

    class { 'eayuncenter::db_init':
      # for mysql init
      mysql_db_name     => $mysql_db_name,
      mysql_username    => $mysql_username,
      mysql_password    => $mysql_password,
      management_vip    => $management_vip,
      # for mongo init
      primary_mongo_ip  => $primary_mongo_ip,
      mongo_db_name     => $mongo_db_name,
      mongo_db_user     => $mongo_db_user,
      mongo_db_password => $mongo_db_password,
      db_tmp_dir        => $db_tmp_dir,
      # init db before main(default) stage
      stage             => 'pre_main',
    }

  }

  package { 'docker':
    ensure => latest,
    before => [
      File['eayunstack_systemd_docker'],
      Service['docker'],
    ],
  }

  file { 'docker_service_dir':
    ensure => directory,
    path   => '/etc/systemd/system/docker.service.d/',
    before => File['eayunstack_systemd_docker'],
  }

  file { 'eayunstack_systemd_docker':
    path   => '/etc/systemd/system/docker.service.d/eayunstack.conf',
    source => 'puppet:///modules/eayuncenter/eayunstack_systemd_docker.conf',
    before => Service['docker'],
    notify => Exec['reload_docker_service_file'],
  }

  exec { 'reload_docker_service_file':
    path        => '/usr/bin',
    command     => 'systemctl daemon-reload',
    refreshonly => true,
    before      => Service['docker'],
  }

  service { 'docker':
    ensure => running,
    enable => true,
  }

  file { 'eayuncenter_config_dir':
    ensure => directory,
    path   => '/etc/eayuncenter/',
  }

  file { 'eayuncenter_config_file':
    ensure  => file,
    path    => '/etc/eayuncenter/eayuncenter.conf',
    mode    => 0640,
    require => File['eayuncenter_config_dir'],
  }

  eayuncenter_config {
    'DEFAULT/mysql_url':      value => $mysql_url;
    'DEFAULT/mysql_user':     value => $mysql_username;
    'DEFAULT/mysql_pass':     value => $mysql_password;
    'DEFAULT/mongo_url':      value => $mongo_url;
    'DEFAULT/mongo_db':       value => $mongo_db_name;
    'DEFAULT/mongo_user':     value => $mongo_db_user;
    'DEFAULT/mongo_pass':     value => $mongo_password;
    'DEFAULT/mongo2_url':     value => $mongo_url;
    'DEFAULT/mongo2_db':      value => $ceilometer_db_name;
    'DEFAULT/mongo2_user':    value => $ceilometer_db_user;
    'DEFAULT/mongo2_pass':    value => $ceilometer_db_pwd;
    'DEFAULT/JAVA_OPTS':      value => $java_opts;
    'DEFAULT/LOGBACK_METHOD': value => $logback_method;
  }

  package { 'eayuncenter-docker-image':
    ensure => latest,
    notify => [
      Exec['remove_old_eayuncenter_container'],
      Exec['remove_old_eayuncenter_image'],
      Exec['load_new_eayuncenter_image'],
      Exec['start_new_eayuncenter_container'],
    ],
  }

  exec { 'remove_old_eayuncenter_container':
    path        => '/usr/bin',
    command     => "docker rm -f ${docker_container_name}",
    onlyif      => "docker ps -a | grep -q ${docker_container_name}",
    refreshonly => true,
    require     => Service['docker'],
  }

  exec { 'remove_old_eayuncenter_image':
    path        => '/usr/bin',
    command     => "docker rmi -f ${docker_image_name}:${docker_image_version}",
    onlyif      => "docker images | grep -q ${docker_image_name}",
    refreshonly => true,
    require     => [
      Service['docker'],
      Exec['remove_old_eayuncenter_container'],
    ],
  }

  exec { 'load_new_eayuncenter_image':
    path        => '/usr/bin',
    command     => 'docker load -i /usr/share/eayuncenter/eayuncenter-image.tar',
    unless      => "docker images | grep -q ${docker_image_name}",
    refreshonly => true,
    require     => [
      Service['docker'],
      Exec['remove_old_eayuncenter_image'],
    ],
    notify      => Exec['start_new_eayuncenter_container'],
  }

  exec { 'start_new_eayuncenter_container':
    path        => '/usr/bin',
    command     => "docker run -d -p 80:8080 --restart=\"always\" --env-file /etc/eayuncenter/eayuncenter.conf --name ${docker_container_name} ${docker_image_name}:${docker_image_version}",
    onlyif      => "docker images | grep -q ${docker_image_name}",
    refreshonly => true,
    require     => [
      Service['docker'],
      File['eayuncenter_config_file'],
      Exec['waiting_for_mysql_db_init_complate'],
      Exec['remove_old_eayuncenter_container'],
      Exec['load_new_eayuncenter_image'],
    ],
  }

  exec { 'waiting_for_mysql_db_init_complate':
    path      => '/usr/bin',
    command   => "mysql -uroot -e \'use $mysql_db_name; select * from dc_datacenter where id=\"$datacenter_id\"' &> /dev/null",
    tries     => 60,
    try_sleep => 5,
    timeout   => 600,
  }

  File['eayuncenter_config_file'] -> Eayuncenter_config<||> -> Package['eayuncenter-docker-image']

  Eayuncenter_config<||> ~> Exec['remove_old_eayuncenter_container']
  Eayuncenter_config<||> ~> Exec['start_new_eayuncenter_container']

  if $ha_mode {
    package{ 'haproxy':
      ensure => latest,
    }

    service { 'haproxy':
      ensure     => running,
      enable     => true,
      hasstatus  => true,
      hasrestart => false,
      provider   => 'pacemaker',
    }

    file { 'haproxy_directory':
      ensure  => directory,
      path    => '/etc/haproxy/conf.d',
      require => Package['haproxy'],
    }

    $primary_controller_nodes = filter_nodes($nodes_hash, 'role', 'primary-controller')
    $controllers = concat($primary_controller_nodes, filter_nodes($nodes_hash, 'role', 'controller'))

    class { 'eayuncenter::haproxy': 
      controllers         => $controllers,
      virtual_ips         => $virtual_ips,
      use_ssl             => false,
    }
  }
}
