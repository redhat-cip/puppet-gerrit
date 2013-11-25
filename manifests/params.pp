# Class: gerrit::params
class gerrit::params {
  $gerrit_group = 'gerrit'
  $gerrit_user = 'gerrit'
  $gerrit_groups = undef

  # Package to install for providing JAVA
  $gerrit_java = $::osfamily ? {
    Debian  => 'openjdk-7-jre-headless',
    default => 'java-1.7.0-openjdk',
  }
  $gerrit_java_home = $::osfamily ? {
    Debian  => "/usr/lib/jvm/java-7-openjdk-${::architecture}/jre",
    default => '/usr/lib/jvm/java-7-openjdk-amd64/jre'
  }
}
