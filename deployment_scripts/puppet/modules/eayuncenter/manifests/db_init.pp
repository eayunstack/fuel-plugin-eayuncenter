class eayuncenter::db_init (
  $management_vip,
  $primary_mongo_ip,
  $mysql_db_name,
  $mysql_username,
  $mysql_password,
  $mongo_db_name,
  $mongo_db_user,
  $mongo_db_password,
  $db_tmp_dir,
) {

  file { 'eayuncenter_share_dir':
    ensure => directory,
    path   => "${db_tmp_dir}",
  }

  class { 'eayuncenter::db_init_mysql':
    mysql_db_name  => $mysql_db_name,
    mysql_username => $mysql_username,
    mysql_password => $mysql_password,
    management_vip => $management_vip,
    db_tmp_dir     => $db_tmp_dir,
  }

  class { 'eayuncenter::db_init_mongo':
    primary_mongo_ip  => $primary_mongo_ip,
    mongo_db_user     => $mongo_db_user,
    mongo_db_password => $mongo_db_password,
    db_tmp_dir        => $db_tmp_dir,
    mongo_db_name     => $mongo_db_name,
  }

}
