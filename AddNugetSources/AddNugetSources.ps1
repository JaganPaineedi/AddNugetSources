try
{
    #Comment out this section for testing
	$nugetFeedServiceEndpoint = Get-VstsInput -Name "NugetFeedServiceEndpoint" -Require
	$pathToNugetExe = Get-VstsInput -Name "PathToNugetExe" -Require
    $nugetSources = Get-VstsInput -Name "NugetSources" -Require
	[boolean]$script:isDotnet = Get-VstsInput -Name "isDotNet" -Require -AsBool

	#Get Url, Username, and Password from service endpoint input
	$getService = Get-VstsEndpoint -Name $nugetFeedServiceEndpoint -Require
	$username = $getService.Auth.parameters.username
	$password = $getService.Auth.parameters.password
	$feedUrl = $getService.Url
    #>
    #
    <#Testing Variables    
	$pathToNugetExe = "C:\CredentialProviderBundle\"
    $nugetSources =  ""
	$username = ""
	$password = ""
	$feedUrl = ""
    #>
}
catch
{
	Write-Output $_.message
}

$sources = $nugetSources.Split("`r`n")
$nugetEXE = "$pathToNugetExe\nuget.exe"
$VSSCredentialFile = "$pathToNugetExe\CredentialProvider.VSS.exe"

if((Test-Path "$nugetEXE") -and (Test-Path "$VSSCredentialFile"))
{
	foreach($source in $sources)
	{
		$sourceUrl = "$feedUrl`_packaging/$source/nuget/v3/index.json"
		try{
			$nugetSources = &$nugetEXE sources
            [boolean]$isUpdated = $false

            for($count = 0; $count -lt $nugetSources.Count; $count++)
            {
                if($nugetSources[$count].tostring() -match "[0-9]+\.")
                {
                    $text = $nugetSources[$count].tostring()
                    $text = $text.Remove(0,$text.IndexOf('.')+1).trim()
                    $text = $text.Remove($text.IndexOf('[')).trim()            
            
                    $sourceObj = New-Object System.Management.Automation.PSObject           
                    $sourceObj | Add-Member -MemberType NoteProperty -Name "SourceName" -Value $text
                    $sourceObj | Add-Member -MemberType NoteProperty -Name "Source" -Value $nugetSources[$count + 1].trim()
                    #$sourceObj
                                        
                    if($sourceObj.Source.ToLower() -eq $sourceUrl.Trim().ToLower() -or $text.ToLower() -eq $source.ToLower())
                    {
                        Write-Host "Source Id: " $sourceObj.SourceName.ToString()
                        Write-Host "SourceUrl: " $sourceUrl.Trim().ToLower()
                        Write-Host "Removing Nuget Source"
                        &$nugetEXE sources remove -name "$($sourceObj.SourceName)" -source "$($sourceObj.Source)"
                        Write-Host "Adding Nuget Source"
						if($script:isDotnet)
						{
							&$nugetEXE sources Add -Name "$($sourceObj.SourceName)" -Source "$sourceUrl" -UserName $username -Password $password -StorePasswordInClearText
						}
						else{
							&$nugetEXE sources Add -Name "$($sourceObj.SourceName)" -Source "$sourceUrl" -UserName $username -Password $password
						}
                        $isUpdated = $true
                    } 
                }
            }
            if(-not $isUpdated)
            {
                Write-Host "Adding Nuget Source"
                if($script:isDotnet)
				{
					Write-Host "Source name: $source"
					Write-Host "Source Url: $sourceUrl"
					&$nugetEXE sources Add -Name "$source" -Source "$sourceUrl" -UserName $username -Password $password -StorePasswordInClearText
				}
				else{
					Write-Host "Source name: $source"
					Write-Host "Source Url: $sourceUrl"
					&$nugetEXE sources Add -Name "$source" -Source "$sourceUrl" -UserName $username -Password $password
				}
            }
		}
		catch{
			Write-Error "##vso[task.logissue type=error;] Unable to add Nuget source $($_.message)"
		}		
	}
}
else
{
	Write-Error "##vso[task.logissue type=error;] Please make sure you entered a valid nuget file path. Also note CredentialProvider.VSS.exe has to be in the same specified directory"
}