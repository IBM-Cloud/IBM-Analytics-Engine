# Preparing to use the IBM Cloud CLI

Follow the instructions mentioned [here](https://cloud.ibm.com/docs/cli?topic=cloud-cli-getting-started#step1-install-idt) to install the IBM Cloud CLI.

Once the installer has completed, launch a new terminal or command window to continue with the steps.

## Login to IBM Cloud

There are three methods to log in depending on your situation
* `ibmcloud login` for regular username and password login.
* `ibmcloud login --sso` for organizations using single signon to log into the IBM Cloud. This will use a generated one-time key as part of the process.
* `ibmcloud login --apikey` if you have created an [api key](https://cloud.ibm.com/docs/iam?topic=iam-manapikey#manapikey) to provide application access.

Depending on the method you will have different initial prompts but once authentication is complete the remaining prompts will be something similar to :-

```
...

Authenticating...
OK

Targeted account John Doe's Account (713c783d9a423a53135fe6793c6581e9) <-> 1444623

Targeted resource group default

                     
API endpoint:     https://api.ng.bluemix.net (API version: 2.92.0)   
Region:           us-south   
User:             jdoe123@us.ibm.com   
Account:          John Doe's Account (713c783d9a423a53135fe6793c6581e9) <-> 1444623  
Resource group:   default   
Org:                 
Space:               

Tip: If you are managing Cloud Foundry applications and services
- Use 'bx target --cf' to target Cloud Foundry org/space interactively, or use 'bx target -o ORG -s SPACE' to target the org/space.
- Use 'bx cf' if you want to run the Cloud Foundry CLI with current Bluemix CLI context.

$
```
