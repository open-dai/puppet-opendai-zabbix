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
class zabbix::install {
	$mirror_url = "http://downloads.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/${zabbix::version}/zabbix-${zabbix::version}.tar.gz"
	$dist_dir = '/home/zabbix/tmp'
	$dist_file = "${dist_dir}/zabbix-${zabbix::version}.tar.gz"
	notice "Download URL: $mirror_url"
	
	group {
		zabbix :
			ensure => present
	}
	user {
		zabbix :
			ensure => present,
			managehome => true,
			gid => 'zabbix',
			require => Group['zabbix'],
			comment => 'Zabbix server'
	}
	
	file {
		$dist_dir :
			ensure => directory,
			owner => 'zabbix',
			group => 'zabbix',
			mode => 0775,
			require => [Group['zabbix'], User['zabbix']]
	}
	notice "Downloading ..."
	# Download the Zabbix distribution ~100MB file
	exec {
		download_zabbix :
			command =>
			"/usr/bin/curl -v -L --progress-bar -o '$dist_file' '$mirror_url'",
			creates => $dist_file,
			user => 'zabbix',
			logoutput => true,
			require => File[$dist_dir],
	}
	
	notice "Downloaded/Present dist file ... extracting"
	# Extract Zabbix
	exec {
		extract_zabbix :
			command => "/bin/tar -xz -f '$dist_file'",
			creates => "/home/zabbix/zabbix-${zabbix::version}",
			cwd => '/home/zabbix',
			user => 'zabbix',
			group => 'zabbix',
			logoutput => true,
#			unless => "/usr/bin/test -d '$jbossas::dir'",
			require => [Group['zabbix'], User['zabbix'], Exec['download_zabbix']]
	}
}
