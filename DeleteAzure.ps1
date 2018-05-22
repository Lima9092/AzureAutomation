
$csv = import-csv AzureStorage.csv 
$csv | foreach-object {
$ResourceGroup = $_.'ResourceGroup'

Remove-AzureRmResourceGroup -Name $ResourceGroup -force
}
