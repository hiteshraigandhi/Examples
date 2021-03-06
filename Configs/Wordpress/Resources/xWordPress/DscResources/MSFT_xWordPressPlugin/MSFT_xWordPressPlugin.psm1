data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData @'
WordPressPluginSetError=Not able to set wordpress plugin {0} to {1}.
'@
}

Import-Module $PSScriptRoot\..\xWordPress_Common

$WordPressPluginGetURI = "{0}/wp-admin/dschelper.php?type=plugin&method={1}"
$WordPressPluginURI = "$WordPressPluginGetURI&name={2}&state={3}"

#copy helper file to correct location
[string] $WordPressSiteDirectory = 'c:\inetpub\Wordpress' #FOR DEMO ONLY:This should not be hard coded.

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

        [parameter(Mandatory = $true)]
		[System.String]
		$URI
	)

    New-WordPressPHPHelper $WordPressSiteDirectory

    # Set the default to 'Disable'
    $State = 'Disabled'

    $result = Invoke-WebRequest -UseBasicParsing -Uri $($WordPressPluginGetURI -f $Uri.TrimEnd('/'),'get') -Verbose:$false

    if($result.StatusCode -eq 200 -and ($result.Content.Trim('ï»¿   ').Contains($Name)))
    {
		    $State = 'Enabled'
    }
        
    return @{
                Name  = $Name
                Uri   = $URI
                State = $State
            }
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[ValidateSet('Enabled','Disabled')]
		[System.String]
		$State = 'Enabled',

        [parameter(Mandatory = $true)]
		[System.String]
		$URI
	)  

    New-WordPressPHPHelper $WordPressSiteDirectory

    Write-Verbose -Message "Setting the plugin $Name to $State ..."        
    $result = Invoke-WebRequest -UseBasicParsing -Uri $($WordPressPluginURI -f $Uri.TrimEnd('/'),'set',$Name.ToLower(),$State.ToLower()) -Verbose:$false

    # If the status code of the request is not 200, there is error
    if ($result.StatusCode -ne 200)
    {
        New-TerminatingError -errorId PluginSetFailed -errorMessage ($($LocalizedData.WordPressPluginSetError) -f $Name, $State) -errorCategory InvalidResult
    }
    else
    {
            Write-Verbose -Message "Plugin $Name is now $State"        
    }
}

function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[ValidateSet('Enabled','Disabled')]
		[System.String]
		$State = 'Enabled',

        [parameter(Mandatory = $true)]
		[System.String]
		$URI
	)

    New-WordPressPHPHelper $WordPressSiteDirectory

    # Check the current state of the plugin
    Write-Verbose -Message "Checking if plugin $Name is $State ..."
    $result = Invoke-WebRequest -UseBasicParsing -Uri ($WordPressPluginURI -f $Uri.TrimEnd('/'),'test',$Name.ToLower(),$State.ToLower()) -Verbose:$false
    
    # If the status code = 200, the request succeeded
    if($result.StatusCode -eq 200)
    {
        # Check for content to be true, after trimming 
        if($result.Content.Trim('ï»¿   ') -eq 'True')
        {
            Write-Verbose -Message "Plugin $Name is $State"
            return $true
        }
        else
        {
            Write-Verbose -Message "Plugin $Name is not $State"
            return $false
        }
    }

    # This code path is not expected, so something is broken
    else
    {
        Throw "Unexpected response $($result.StatusCode)"
    }
}

Export-ModuleMember -Function *-TargetResource