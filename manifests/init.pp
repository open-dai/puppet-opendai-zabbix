# Class: zabbix
#
# This module manages zabbix
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
class zabbix ($version = '2.0.2', $dbhost = 'localhost',$timezone='Rome') {
  $ZabbixDBHost = $dbhost
  $ZabbixDBName = "zabbix"
  $ZabbixDBSchema = "zabbix"
  $ZabbixDBUser = "zabbix"
  $ZabbixDBPassword = "zabbix"

  package { 'httpd': ensure => installed, }

  package { 'php':
    ensure  => installed,
    require => Package['httpd'],
  }

  package { 'php-common':
    ensure  => installed,
    require => Package['httpd'],
  }

  package { 'php-gd':
    ensure  => installed,
    require => Package['php'],
  }

  package { 'php-mysql':
    ensure  => installed,
    require => Package['php'],
  }

  package { 'php-xml':
    ensure  => installed,
    require => Package['php'],
  }

  package { 'php-mbstring':
    ensure  => installed,
    require => Package['php'],
  }

  augeas { 'php.ini-timezone':
    context => "/files/etc/php.ini",
    changes => ["set Date/date.timezone \"Europe/${timezone}\"",],
    require => Package['php'],
  }

  package { 'fping': ensure => installed, }

  package { 'net-snmp': ensure => installed, }

  package { 'zabbix-server':
    ensure  => installed,
    require => Package['fping', 'net-snmp'],
  }

  package { 'zabbix-server-mysql':
    ensure  => installed,
    require => Package['zabbix-server'],
  }

  package { 'zabbix-web':
    ensure  => installed,
    require => Package['zabbix-server'],
  }

  package { 'zabbix-web-mysql':
    ensure  => installed,
    require => Package['zabbix-server'],
  }

  file { "/etc/zabbix/zabbix_server.conf":
    ensure  => "present",
    content => template("zabbix/zabbix_server.conf.erb"),
    require => Package['zabbix-server'],
  }

  file { "/tmp/data.sql":
    ensure  => "present",
    source  => "puppet:///modules/zabbix/mysql/data.sql",
    require => Package['zabbix-server'],
  }

  file { "/tmp/images.sql":
    ensure  => "present",
    source  => "puppet:///modules/zabbix/mysql/images.sql",
    require => Package['zabbix-server'],
  }

  file { "/tmp/schema.sql":
    ensure  => "present",
    source  => "puppet:///modules/zabbix/mysql/schema.sql",
    require => Package['zabbix-server'],
  }

  exec { "load-schema.sql":
    command => "/usr/bin/mysql -h$ZabbixDBHost -u$ZabbixDBUser -p$ZabbixDBPassword $ZabbixDBName < /tmp/schema.sql && touch /root/schema.sql.semaphore",
    #unless  => "/usr/bin/mysql -h$ZabbixDBHost -u$ZabbixDBUser -p$ZabbixDBPassword $ZabbixDBName -e \"show tables like 'hosts';\"",
    creates => "/root/schema.sql.semaphore",
    require => [File['/tmp/schema.sql'], Package['mysql']],
  }

  exec { "load-images.sql":
    command => "/usr/bin/mysql -h$ZabbixDBHost -u$ZabbixDBUser -p$ZabbixDBPassword $ZabbixDBName < /tmp/images.sql && touch /root/images.sql.semaphore",
    #    unless  => "/usr/bin/mysql
    #    -h$ZabbixDBHost -u$ZabbixDBUser -p$ZabbixDBPassword $ZabbixDBName -e \"select * from images where name ='Network_(96)';\"",
    creates => "/root/images.sql.semaphore",
    require => [File['/tmp/images.sql'], Exec['load-schema.sql']],
  }

  exec { "load-data.sql":
    command => "/usr/bin/mysql -h$ZabbixDBHost -u$ZabbixDBUser -p$ZabbixDBPassword $ZabbixDBName < /tmp/data.sql && touch /root/data.sql.semaphore",
    #    unless  => "/usr/bin/mysql -h$ZabbixDBHost -u$ZabbixDBUser -p$ZabbixDBPassword $ZabbixDBName -e \"select * from hosts where
    #    host='Template SNMP Interfaces';\"",
    creates => "/root/data.sql.semaphore",
    require => [File['/tmp/data.sql'], Exec['load-images.sql']],
  }

  notice("/usr/bin/mysql -h$ZabbixDBHost -u$ZabbixDBUser -p$ZabbixDBPassword $ZabbixDBName -c \"show tables like 'hosts';\"")
  notice("/usr/bin/mysql -h$ZabbixDBHost -u$ZabbixDBUser -p$ZabbixDBPassword $ZabbixDBName -e \"select * from hosts where host='Template SNMP Interfaces';\""
  )

  file { "/etc/zabbix/web/zabbix.conf.php":
    ensure  => "present",
    owner =>"apache",
    group=>"apache",
    content => template("zabbix/zabbix.conf.php.erb"),
    require => [Package['zabbix-server'], Exec['load-data.sql']],
  }

  service { 'zabbix-server':
    ensure  => running,
    require => [Package['zabbix-server'], Exec['load-data.sql'], File['/etc/zabbix/zabbix_server.conf']],
  }
}
