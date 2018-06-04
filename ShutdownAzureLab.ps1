$csv = import-csv AzureVMS.csv 
$csv | foreach-object {
    $ResourceGroup = $_.'ResourceGroup' 
    $VMName = $_.'VMName'

    Stop-AzureRmVM -ResourceGroupName $ResourceGroup -Name $VMName -Force
}