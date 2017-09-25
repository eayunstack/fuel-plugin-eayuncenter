# HA configuration for EayunCenter
class eayuncenter::haproxy (
  $use_ssl = false,
  $controllers,
  $virtual_ips,
) {

  Haproxy::Service        { use_include => true }
  Haproxy::Balancermember { use_include => true }

  Eayuncenter::Haproxy_service {
    server_names        => filter_hash($controllers, 'name'),
    ipaddresses         => filter_hash($controllers, 'internal_address'),
    virtual_ips         => $virtual_ips,
  }

  eayuncenter::haproxy_service { 'eayuncenter':
    order          => '180',
    listen_port    => 80,
    define_cookies => true,

    haproxy_config_options => {
      'option'  => ['forwardfor', 'httpchk', 'httpclose', 'httplog'],
      'rspidel' => '^Set-cookie:\ IP=',
      'balance' => 'source',
      'mode'    => 'http',
      'cookie'  => 'SERVERID insert indirect nocache',
      'capture' => 'cookie vgnvisitor= len 32',
      'timeout' => ['client 3h', 'server 3h'],
    },

    balancermember_options => 'check inter 2000 fall 3',
  }

  if $use_ssl {
    eayuncenter::haproxy_service { 'eayuncenter-ssl':
      order       => '181',
      listen_port => 443,

      haproxy_config_options => {
        'option'      => ['ssl-hello-chk', 'tcpka'],
        'stick-table' => 'type ip size 200k expire 30m',
        'stick'       => 'on src',
        'balance'     => 'source',
        'timeout'     => ['client 3h', 'server 3h'],
        'mode'        => 'tcp',
      },

      balancermember_options => 'weight 1 check',
    }
  }
}
