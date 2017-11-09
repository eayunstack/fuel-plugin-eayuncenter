$fuel_settings = parseyaml($astute_settings_yaml)
if $fuel_settings {
  class { 'eayuncenter': }
}
