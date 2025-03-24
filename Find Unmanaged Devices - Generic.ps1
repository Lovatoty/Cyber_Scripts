#File to comare AD assets to the list of Sensors in Crowdstrike
#Can be adapted to other platforms with little to no effort

#This PS Script loads a CSV Files containing the hostnames from crowdstrike
#It then pulls computers currerently joined to AD, and searchs the CSV file
#If it does not find the hostname in the CVS file, it is likely not managed by CS, and the hostname is printed to the console

#TODO: Allow found assets to be exported to a file.
#     - Allow user to select a file
#ToDo: Utilize CS API

#Created by Tyler Lovato
#Sepember 2022
#Updated March 2025 to remove org specific info.

#needed for file Dialog
Add-Type -AssemblyName System.Windows.Forms
$OpenFileExplorer = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileExplorer.InitialDirectory = [Environment]::GetFolderPath('Desktop')
$OpenFileExplorer.Filter = 'CSV Files (*.csv)|*.csv'
$OpenFileExplorer.Multiselect = $false
$FileDialogResponse = $OpenFileExplorer.ShowDialog()
if($FileDialogResponse -ne 'OK'){
    exit
}
Write-Host -ForegroundColor Blue "Openinf File: " $OpenFileExplorer.FileName
$CSData = Import-Csv -Path $OpenFileExplorer.FileName


#filters accounts older then 30 days.
#can be changed as needed
$LastLoginCutoff = (Get-Date).AddDays(-30).Date

#Path to export a file to
$dateTime = Get-Date -Format "yyyyMMddTHHmm"
$ExportPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop) + "\unmanagedAssets" + $dateTime.toString() + ".csv"
Write-Host $ExportPath


#This section uses a hashtable for organization. It will need to be modified to fit your needs
#We need an array of hashtables, to cycle through each OU
#currently not filtering Excluded OUs, but leaving in for future use.
#You may have something similar as well.
$hashArray = @(
@{Unit = 'Unit01'
OU = 'OU=Unit01,DC=example,DC=net'
ExcludedOU = '*OU=(Excluded Assets),OU=Unit01,DC=example,DC=net'},
@{Unit = 'Unit02'
OU = 'OU=Unit02,DC=example,DC=net'
ExcludedOU = '*OU=(Excluded Assets),OU=Unit02,DC=example,DC=net'},
@{Unit = 'Unit03'
OU = 'OU=Unit03,DC=example,DC=net'
ExcludedOU = '*OU=(Excluded Assets),OU=Unit03,DC=example,DC=net'}
)

#for counting the total amount of items
$TotalItems = 0
#Cycles through each Unit
foreach($hashValue in $hashArray){
    #Writes which Unit is being run against the CSV
    Write-Host -ForegroundColor Green "Checking Devices in " $hashValue.Unit
    
    #This is the actual lookup in AD
    $HostNameList = Get-ADComputer -Filter {lastlogondate -gt $LastLoginCutoff -and Enabled -eq 'True'} -SearchBase $hashValue.OU -Properties IPv4Address, Description
    #Takes the list from AD, checks each asset
    foreach($SingleHostName in $HostNameList){
        if($CSData.Hostname -notcontains $SingleHostName.name){
            Write-Host $SingleHostName.Name "`t" $SingleHostName.IPv4Address "`t" $SingleHostName.Description
            $SingleHostName | Export-Csv -Path $ExportPath -Append
            $TotalItems++
        }    
    }
}
Write-Host -ForegroundColor Green "Found " $TotalItems " Items."
pause