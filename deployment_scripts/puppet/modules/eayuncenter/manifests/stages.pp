class eayuncenter::stages {
  stage { 'pre_main': before => Stage['main'] }
}
