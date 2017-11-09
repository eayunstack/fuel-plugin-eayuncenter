# Register a service with HAProxy
define eayuncenter::haproxy_service (
  $order,
  $server_names,
  $ipaddresses,
  $listen_port,
  $virtual_ips,

  $mode                   = undef,
  $haproxy_config_options = { 'option' => ['httplog'], 'balance' => 'roundrobin' },
  $balancermember_options = 'check',
  $balancermember_port    = $listen_port,
  $define_cookies         = false,

  # use active-passive failover, mark all backends except the first one
  # as backups
  $define_backups         = false,

) {

  haproxy::listen { $name:
    order     => $order,
    ipaddress => $virtual_ips,
    ports     => $listen_port,
    options   => $haproxy_config_options,
    mode      => $mode,
  }

  haproxy::balancermember { $name:
    order             => $order,
    listening_service => $name,
    server_names      => $server_names,
    ipaddresses       => $ipaddresses,
    ports             => $balancermember_port,
    options           => $balancermember_options,
    define_cookies    => $define_cookies,
    define_backups    => $define_backups,
  }

  # Dirty hack, due Puppet can't send notify between stages
  exec { "haproxy reload for ${name}":
    command     => 'export OCF_ROOT="/usr/lib/ocf"; ip netns exec haproxy /usr/lib/ocf/resource.d/mirantis/ns_haproxy reload',
    path        => '/usr/bin:/usr/sbin:/bin:/sbin',
    logoutput   => true,
    provider    => 'shell',
    tries       => 10,
    try_sleep   => 10,
    returns     => [0, ''],
    require     => [Service['haproxy'], Haproxy::Listen[$name], Haproxy::Balancermember[$name]],
  }
}
