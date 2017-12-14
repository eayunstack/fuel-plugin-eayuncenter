class eayuncenter::db_init_mongo (
  $primary_mongo_ip,
  $mongo_db_name,
  $mongo_db_user,
  $mongo_db_password,
  $db_tmp_dir,
) {

  # for mongo command
  package { 'mongodb':
    ensure => latest,
  }

  file { "${db_tmp_dir}/mongo_create_index.js":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('eayuncenter/mongo_create_index.js.erb'),
  }

  file { "${db_tmp_dir}/init_mongo.sh":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
    content => template('eayuncenter/init_mongo.sh.erb'),
  }

  exec { 'init_mongo_db':
    command  => "${db_tmp_dir}/init_mongo.sh",
    path     => '/usr/bin',
    user     => "root",
    provider => shell,
    require  => [
      Package['mongodb'],
      File["${db_tmp_dir}/mongo_create_index.js", "${db_tmp_dir}/init_mongo.sh"],
    ],          
  }

}
