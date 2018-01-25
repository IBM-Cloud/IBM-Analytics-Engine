# Preparing to use the IBM Cloud CLI

Full documentation of the [IBM Cloud CLI](https://console.bluemix.net/docs/cli/index.html#downloads) is available here. It includes a number of tools and addons including the Cloud Foudry API. The following is an abridged set of instructions focussed on IBM Analytics Engine use cases.

Download the latest CLI version for your platform from [here](https://console.bluemix.net/docs/cli/reference/bluemix_cli/all_versions.html#ibm-cloud-cli-installer-all-versions) and install as prompted.

Once the installer has completed, launch a new terminal or command window to continue with the steps.

## Select a geographical region where IAE will be deployed and managed

Use the command `bx regions` to list current geographies you can deploy services in if you dont know the right API endpoint already.

```
bx regions
```

```
Listing Bluemix regions...

Name       Geolocation      Customer   Deployment   Domain               CF API Endpoint                  Type   
eu-de      Germany          IBM        Production   eu-de.bluemix.net    https://api.eu-de.bluemix.net    public   
au-syd     Sydney           IBM        Production   au-syd.bluemix.net   https://api.au-syd.bluemix.net   public   
us-south   US South         IBM        Production   ng.bluemix.net       https://api.ng.bluemix.net       public   
eu-gb      United Kingdom   IBM        Production   eu-gb.bluemix.net    https://api.eu-gb.bluemix.net    public  
```

Set the endpoint for your desired region using the `bx api` command.

```
bx api https://api.ng.bluemix.net  
```

```
Setting api endpoint to https://api.ng.bluemix.net...
OK

API endpoint: https://api.ng.bluemix.net (CF API version: 2.92.0)
Not logged in. Use 'bx login' to log in.
```


## Login to IBM Cloud

There are three methods to log in depending on your situation
* `bx login` for regular username and password login.
* `bx login --sso` for organizations using single signon to log into the IBM Cloud. This will use a generated one-time key as part of the process.
* `bx login --apikey` if you have created an [api key](https://console.bluemix.net/docs/iam/apikeys.html#manapikey) to provide application access.

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
Now you can select the right Cloud Foundry Org and Space to work in for your IAE instances interactively using the command `bx target --cf` . 

```
bx target --cf
```

```
Targeted org jdoe123@us.ibm.com


Select a space (or press enter to skip):
1. dev
2. prod

Enter a number> 1
Targeted space dev


                     
API endpoint:     https://api.ng.bluemix.net (API version: 2.92.0)   
Region:           us-south   
User:             jdoe123@us.ibm.com   
Account:          John Doe's Account (713c783d9a423a53135fe6793c6581e9) <-> 1444623   
Resource group:   default   
Org:              jdoe123@us.ibm.com  
Space:            dev   
```

Once you know the selections you can use the command `bx target -o [ORG] -s [SPACE]` with those values.

```
bx target -o jdoe123@us.ibm.com -s dev
```

## Scripting login

After manually stepping through these steps, you may want to script them. Using an API key login method for this is the simplest option for this. 

```
bx api https://api.ng.bluemix.net
bx login --apikey 32wBLEK*D8bOIX7Dc8jLn2bmhHDOLNRmiQ_c_FSKFml2
bx target -o jdoe123@us.ibm.com -s dev
```

