# Import required librearies for Sharepoint Client
Add-Type -Path "libraries\Microsoft.SharePoint.Client.dll"
Add-Type -Path "libraries\Microsoft.SharePoint.Client.Runtime.dll"

$Logfile = "importWorfkflow.log"

function LogWrite([string]$logstring, [string]$statusColor = "Green") {
	Add-content $Logfile -value $logstring
	Write-Host $logstring -ForegroundColor $statusColor
}

function New-Context([String]$WebUrl) {
	$context = New-Object Microsoft.SharePoint.Client.ClientContext($WebUrl)
	$context.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
	$context
}

function HandleMixedModeWebApplication(){
	  param([Parameter(Mandatory=$true)][object]$clientContext)
	  Add-Type -TypeDefinition @"
	  using System;
	  using Microsoft.SharePoint.Client;

	  namespace Toth.SPOHelpers
	  {
	      public static class ClientContextHelper
	      {
	          public static void AddRequestHandler(ClientContext context)
	          {
	              context.ExecutingWebRequest += new EventHandler<WebRequestEventArgs>(RequestHandler);
	          }

	          private static void RequestHandler(object sender, WebRequestEventArgs e)
	          {
	              //Add the header that tells SharePoint to use Windows authentication.
	              e.WebRequestExecutor.RequestHeaders.Remove("X-FORMS_BASED_AUTH_ACCEPTED");
	              e.WebRequestExecutor.RequestHeaders.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f");
	          }
	      }
	  }
"@ -ReferencedAssemblies "libraries\Microsoft.SharePoint.Client.dll", "libraries\Microsoft.SharePoint.Client.Runtime.dll";
	  [Toth.SPOHelpers.ClientContextHelper]::AddRequestHandler($clientContext);
}



Try {

	$configurations = Get-Content 'configurations.json' | Out-String | ConvertFrom-Json
	LogWrite "Json has been Loadded successfully."

	$siteCollectionUrl= $configurations.webURL
	$context = New-Context -WebUrl $siteCollectionUrl
	$isNotValidCredentials = $true
	$credentials = $null;


	if ($configurations.MixedAuthenticationMode) {
		$context.AuthenticationMode = [Microsoft.SharePoint.Client.ClientAuthenticationMode]::Default
		HandleMixedModeWebApplication $context
	}

	if ($configurations.useStaticCredentials) {
		$credentials = New-Object System.Net.NetworkCredential($configurations.username, $configurations.password, $configurations.domain)
		$context.Credentials = $credentials
	}else{
		# Check the validity of credential and repeat the proccess
		# if they are not valid
		while($isNotValidCredentials -eq $true){
			try{
				LogWrite "Input your credentials:"
				$credentials = Get-Credential
				$context.Credentials = $credentials.GetNetworkCredential()

				# Check if the credentials is valid
				$web = $context.Web
				$context.Load($web)
				$context.ExecuteQuery()

				# Valid Credential
				$isNotValidCredentials = $false

			}catch{
				$ErrorMessage = $_.Exception.Message
				LogWrite  "$($ErrorMessage)" Red

				if ($ErrorMessage -like "*(401) Unauthorized*") {
					# not valid credentials
					LogWrite  "Wrong Credential" Red
				}else {
					# Error other Credential validity
				    $isNotValidCredentials = $false
				}
			}
		}
	}


	LogWrite "Connection to Site collection has been done successfully. - $($siteCollectionUrl)"


	#Nintex Web Service URL
	$WebSrvUrl=$configurations.webURL+"_vti_bin/nintexworkflow/workflow.asmx"

	LogWrite "Initialize Proxy..." yellow



<#-Credential $configurations.username#>
	$proxy=New-WebServiceProxy -Uri $WebSrvUrl -UseDefaultCredential
	$proxy.timeout = 600000; # 10 Minutes
	$proxy.URL=$WebSrvUrl


	foreach ($element in $configurations.Lists) {

			LogWrite  "Start loading $($element.Title)"

			# Load the current list
			$currentList = $context.Web.Lists.GetByTitle($element.Title)
			$context.Load($currentList)
			$context.ExecuteQuery()

			LogWrite  "List was loadded successfully. List Name:  $($element.Title)"

			LogWrite  "Start loading workflow file"
			#Path of the NWF Workflow File
			$WorkflowFile= $element.workflowLocation
			#Get the Workflow from file
			$NWFcontent = get-content $WorkflowFile
			LogWrite  "Workflow Loaded successfully"

			LogWrite  "Start Publishing Workflow"
			$proxy.PublishFromNWFXml($NWFcontent, $element.Title ,$element.workflowName, $true)
			LogWrite  "Workflow has been imported successfully, on List Name:  $($element.Title)"
	}

	LogWrite "Completed successfully."
	Read-Host "Press Enter to exit"

	$context.Dispose()

}Catch {
	$ErrorMessage = $_.Exception.Message
	LogWrite  "Error: $($ErrorMessage)." red
	Read-Host "Press Enter to exit"
}
