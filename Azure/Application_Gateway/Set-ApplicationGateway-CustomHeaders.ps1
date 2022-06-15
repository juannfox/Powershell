#Input variables
$ApplicationGateway_Name=Read-Host "Application Gateway name"
$ApplicationGateway_ResourceGroup=Read-Host "Resource Group name"
$ApplicationGateway_Subscription=Read-Host "Subscription name"
$RewriteRuleSet_Name=Read-Host "Define a Rewrite-Rule-Set name"

#Headers in Hashtable format (key=value), where "key" is the Header Name and "value" is the Header Value.
#To add new headers, add a new Hashtable with a variable named $HeaderHashtable_<Number> and increase the number of the lastest header by one.
$HeaderHashtable_1=@{Name="X-Frame-Options";Value="SAMEORIGIN"}
$HeaderHashtable_2=@{Name="Referrer-Policy";Value="Strict-Origin"}
$HeaderHashtable_3=@{Name="Strict-Transport-Security";Value="max-age=31536000; includeSubDomains; preload"}
$HeaderHashtable_4=@{Name="X-Content-Type-Options";Value="nosniff"}

#Hashtable collection (list) with the Header configs stored before on intentionally named variables ($HeaderHashtable_<Number>).
$Headers_Collection=foreach ($VariableName in (Get-Variable).name){if ($VariableName.startswith("HeaderHashtable_")){(Get-Variable -Name $VariableName).Value}}

#Changes context (Subscription)
Set-AzContext -Subscription $ApplicationGateway_Subscription
#Gets the object for the APPGW
$ApplicationGateway = Get-AzApplicationGateway -Name $ApplicationGateway_Name -ResourceGroupName $ApplicationGateway_ResourceGroup
#Empty collection
$RewriteRule_List=@()

#Goes through each header in the list and sets up the necessary config objects
foreach ($Header in $Headers_Collection){
    #Extracts Header Name and Value
    $Header_Name=$Header["Name"]
    $Header_Value=$Header["Value"]
    #Sets Rewrite-Rule-Set-Name in uppercase
    $RewriteRule_Name=$Header_Name.toUpper()
    #Sets up a header rewrite rule object
    $Header_Configuration = New-AzApplicationGatewayRewriteRuleHeaderConfiguration -HeaderName $Header_Name -HeaderValue $Header_Value
    #Sets up an action set object with the previous header rw rule
    $ActionSet = New-AzApplicationGatewayRewriteRuleActionSet -ResponseHeaderConfiguration $Header_Configuration
    #Sets up the rule object with the action set previously created
    $RewriteRule = New-AzApplicationGatewayRewriteRule -Name $RewriteRule_Name -ActionSet $ActionSet
	#Adds the rule object to the list
	$RewriteRule_List+=$RewriteRule
}

#Creates a rule set with all the rule objects added to the list
$RewriteRuleSet = New-AzApplicationGatewayRewriteRuleSet -Name $RewriteRuleSet_Name -RewriteRule $RewriteRule_List
#Sets up the application gateway with the new rule set
Add-AzApplicationGatewayRewriteRuleSet -ApplicationGateway $ApplicationGateway -Name $RewriteRuleSet_Name -RewriteRule $RewriteRuleSet.RewriteRules
Set-AzApplicationGateway -ApplicationGateway $ApplicationGateway