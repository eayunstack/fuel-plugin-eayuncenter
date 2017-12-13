class eayuncenter::db_init_mysql (
  $mysql_db_name,
  $mysql_username,
  $mysql_password,
  $management_vip,
  $db_tmp_dir,
) {
  $datacenter_id = $::fuel_settings['eayuncenter']['datacenter_id']

  $keystone_auth_url       = "http://${::fuel_settings['management_vip']}:5000/v2.0/"
  $keystone_admin_name     = $::fuel_settings['access']['user']
  $keystone_admin_password = $::fuel_settings['access']['password']
  $keystone_tenant_name    = $::fuel_settings['access']['tenant']
  $keystone_tenant_id      = get_tenant_id($keystone_auth_url, $keystone_admin_name, $keystone_admin_password, $keystone_tenant_name)

  $fuel_ip          = $::fuel_settings['master_ip']
  $fuel_auth        = $::fuel_settings['eayuncenter']['fuel_auth']
  $fuel_tenant_name = $::fuel_settings['eayuncenter']['fuel_tenant_name']
  $fuel_tenant_id   = $::fuel_settings['eayuncenter']['fuel_tenant_id']

  $multi_extnet_enabled = $::fuel_settings['neutron-ext-net']['metadata']['enabled']
  if $multi_extnet_enabled {
    $multi_extnet = 1
  } else {
    $multi_extnet = 0
  }
  $multi_extnet_vlan_min = $::fuel_settings['neutron-ext-net']['ext_vlan_min']
  $multi_extnet_vlan_max = $::fuel_settings['neutron-ext-net']['ext_vlan_max']
  $multi_extnet_vlan_range = "$multi_extnet_vlan_min:$multi_extnet_vlan_max"

  $segmentation_type = $::fuel_settings['quantum_settings']['L2']['segmentation_type']
  if $segmentation_type == 'gre' {
    $tenant_net_type = '1'
    $tenant_net_id_range = $::fuel_settings['quantum_settings']['L2']['tunnel_id_ranges']
  } else {
    $tenant_net_type = '0'
    $tenant_net_id_range = $::fuel_settings['quantum_settings']['L2']['phys_nets']['physnet2']['vlan_range']
  }

  file { "${db_tmp_dir}/mysql_init_database.sql":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('eayuncenter/mysql_init_database.sql.erb'),
  }

  file { "${db_tmp_dir}/mysql_init_datacenter.sql":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('eayuncenter/mysql_init_datacenter.sql.erb'),
  }

  file { "${db_tmp_dir}/init_mysql.sh":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
    content => template('eayuncenter/init_mysql.sh.erb'),
  }

  exec { 'init_mysql_db':
    command  => "${db_tmp_dir}/init_mysql.sh",
    path     => '/usr/bin',
    user     => "root",
    provider => shell,
    require  => File["${db_tmp_dir}/mysql_init_database.sql", "${db_tmp_dir}/mysql_init_datacenter.sql", "${db_tmp_dir}/init_mysql.sh"]
  }

}
