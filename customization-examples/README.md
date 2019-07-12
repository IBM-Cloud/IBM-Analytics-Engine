# Creating and customizing the IBM Analytics Engines from a command line

The goal of these tutorials is to help you understand the mechanics of deploying an instance of IAE with or without customization for your purposes using the IBM Cloud command line. 

Once you complete the tutorial, you will be familliar with the steps to create new clusters, validate customizations are applied, diagnose them if needed and delete them when done. Although you will have all the commands needed to manage custom cluster lifecycle, this tutorial does not address automating cluster creation.

Many customizations can be performed after the instance has been created even dynamically when using it through data science tools like Jupyter notebooks. 

However, there are situations where changes and additions need to be baked into a foundation regardless of what application or experience is using the engine. The methods described here allow you not only to modify an indivitual clusters but to create a repeatable baseline configuration across multiple clusters that will allow you to tear down a cluster between uses and rebuild it when workloads return with exactly the same capabilities and configurations.

## Your IBM Cloud organization

The structure of IBM Cloud provides ways to organize resources in a number of ways. It is important to know how you or your organization is using the IBM Cloud so that when you create or change instances of IAE you will be using the right constructs. 

Find out what your company is using for:

* Resource Group 
* Region
* Account

These selections should be visible at the top of the page in IBM Cloud when you are in Dashboard views. For further understanding of how to use them to organize your resources refer to [IBM Cloud documentation](https://cloud.ibm.com/docs/resources?topic=resources-resource)


## Getting set up and connected to IBM Cloud

Follow the instructions [here](ibmcloudlogin.md) to set up your workstation, login and select the right options for your organization to manage IBM Cloud services.

## Creating standard and custom IAE clusters

Once you have your workstation configured and connected to the IBM Cloud you are ready to create IAE clusters

[Create IAE instances from the command line](createiaeinstances.md) will guide you through the steps to create repeatable IAE instances using configuration options.

Now you know the basics you can try different customizations.

[Create a custom IAE instance with Avro](createiaeinstancescustomavro.md)

[Create a custom IAE instance using a Compose MySQL instance for an IAE cluster Hive Metastore](createiaeinstancesexternalhivemetastore.md)

If you have problems with a bootstrap customization script.

[How to debug your boostrap script](bootstrapscriptdebugging.md)

