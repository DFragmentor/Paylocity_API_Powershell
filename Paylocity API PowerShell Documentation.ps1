#Paylocity API PowerShell documentation and examples
#Created by Mitch Miller - http://mitchmillerjr.com/

#Authentication----------------------------------------------------------

#API Authentication Information
$accesstokenurl = "https://apisandbox.paylocity.com/IdentityServer/connect/token" #Edit this line for either testing or production
$granttype = "client_credentials"
$scope = "WebLinkAPI"
$clientID = "#Your client ID here#"
$clientsecret = ConvertTo-SecureString "#Your client seceret here#" -AsPlainText -Force
$cred = New-Object Management.Automation.PSCredential ($clientID, $clientsecret)

#Create Bearer Token and store it in a variable
$token = (Invoke-RestMethod -Body @{ "grant_type" = "$granttype";"scope" = "$scope"} -Authentication Basic -Method Post -Uri $accesstokenurl -Credential $cred).access_token
$secure = ConvertTo-SecureString $token -AsPlainText -Force

#Reading data----------------------------------------------------------

#Read data from Paylocity examples
$companyID = "#Your Company ID#"

#List employees by employeeID. Will default first 25
Invoke-RestMethod -Uri 'https://apisandbox.paylocity.com/api/v2/companies/$companyID/employees' -Authentication OAuth -Token $secure

#List all employees by employeeID. Maximum is 5000. Adjust pagesize to suit your need
Invoke-RestMethod -Uri 'https://apisandbox.paylocity.com/api/v2/companies/$companyID/employees?pagesize=5000' -Authentication OAuth -Token $secure

#Using 1 employee as an example, read user values
$list = Invoke-RestMethod -Uri 'https://apisandbox.paylocity.com/api/v2/companies/$companyID/employees?pagesize=1' -Authentication OAuth -Token $secure
foreach($employeeID in $list.employeeId){ 
    
    Invoke-RestMethod -Uri https://apisandbox.paylocity.com/api/v2/companies/$companyID/employees/$employeeID -Authentication OAuth -Token $secure
    
}


#Usering 1 employee as an example, put user values in a variable to be easily read and used in scripts.
$list = Invoke-RestMethod -Uri 'https://apisandbox.paylocity.com/api/v2/companies/$companyID/employees?pagesize=1' -Authentication OAuth -Token $secure
foreach($employeeID in $list.employeeId){ 
    
    $payuser = Invoke-RestMethod -Uri https://apisandbox.paylocity.com/api/v2/companies/$companyID/employees/$employeeID -Authentication OAuth -Token $secure

#View user's first name, last name and employee status.
    $payuser.firstName
    $payuser.lastName
    $payuser.status.employeeStatus
    
}


#Encryption----------------------------------------------------------

#Generate the unencrypted JSON payload to POST/PUT
#Example setting phone number and email address for a known user. These can be pulled into variable from other systems like Active Directory
$content = @{workAddress = @{'phone'='5551234567';'emailAddress'='User@email.com'}} | ConvertTo-Json

#Create a Key and IV:
$RNG = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$AESEncryptionKey     = [System.Byte[]]::new(32)
$RNG.GetBytes($AESEncryptionKey)
$InitializationVector = [System.Byte[]]::new(16)
$RNG.GetBytes($InitializationVector)

#Create a AES Crypto Provider:
$AESCipher = New-Object System.Security.Cryptography.AesCryptoServiceProvider

#Add the Key and IV to the Cipher
$AESCipher.Key = $AESEncryptionKey
$AESCipher.IV = $InitializationVector

#Encrypt this JSON payload using your own key and IV (NOT with the Paylocity public key)
#Encrypt data with AES: 
$UnencryptedJSON = [System.Text.Encoding]::UTF8.GetBytes($content)
$Encryptor = $AESCipher.CreateEncryptor()
$EncryptedJSON = $Encryptor.TransformFinalBlock($UnencryptedJSON, 0, $UnencryptedJSON.Length)

#Transforms the data to string format
$CipherText = [System.Convert]::ToBase64String($EncryptedJSON)

#RSA Encrypt key with Paylocity public key
$PaylocityPublicKey = "<RSAKeyValue><Modulus>#Your Paylocity Public Key#</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>"
$rsa = New-Object -TypeName System.Security.Cryptography.RSACryptoServiceProvider
$rsa.FromXmlString($PaylocityPublicKey)
$encryptedBytes = $rsa.Encrypt($AESCipher.Key, $false)
$EncodedKey =[Convert]::ToBase64String($encryptedBytes)
$EncodedIV =[Convert]::ToBase64String($AESCipher.IV)


#Create secured JSON
$body = @{secureContent = @{'key'=$EncodedKey;'iv'=$EncodedIV;'content'=$CipherText}} | ConvertTo-Json

#Send information to Paylocity
Invoke-RestMethod -Body $body -ContentType "application/json" -Uri https://apisandbox.paylocity.com/api/v2/companies/$companyID/employees/$employeeID -Method Patch -Authentication OAuth -Token $secure


#Cleanup the Cipher and KeyGenerator
$AESCipher.Dispose()
$RNG.Dispose()
$rsa.Dispose() 