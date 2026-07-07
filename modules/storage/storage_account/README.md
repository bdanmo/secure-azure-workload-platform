# Storage Account Module

Terraform module for creating Azure Storage Accounts with comprehensive configuration options and security best practices.

## Features

- **Flexible resource group input**: Accepts both resource group objects and names
- **Security by default**: HTTPS-only, TLS 1.2, no public blob access
- **Comprehensive configuration**: All major storage account settings supported
- **Container creation**: Optional blob containers with access control
- **Network restrictions**: IP rules and VNet integration support
- **Blob properties**: Versioning, retention policies, CORS rules
- **Consistent tagging**: Automatic purpose and management tags

## Usage

### Basic Storage Account

```hcl
module "basic_storage" {
  source = "../modules/storage/storage_account"
  
  storage_account_name = "myappstorage001"
  resource_group       = "rg-myapp"
  purpose             = "application_data"
}
```

### Function App Storage

```hcl
module "function_storage" {
  source = "../modules/storage/storage_account"
  
  storage_account_name = "myfuncstorage001"
  resource_group       = azurerm_resource_group.main
  purpose             = "function_app"
  
  # Function apps typically need these containers
  containers = [
    {
      name                  = "azure-webjobs-hosts"
      container_access_type = "private"
    },
    {
      name                  = "azure-webjobs-secrets"
      container_access_type = "private"
    }
  ]
}
```

### Storage with Network Restrictions

```hcl
module "secure_storage" {
  source = "../modules/storage/storage_account"
  
  storage_account_name          = "securestorage001"
  resource_group               = "rg-secure"
  public_network_access_enabled = true
  
  network_rules = {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = ["203.0.113.0/24"]
    virtual_network_subnet_ids = [
      data.azurerm_subnet.trusted.id
    ]
  }
}
```

### Storage with Blob Properties

```hcl
module "versioned_storage" {
  source = "../modules/storage/storage_account"
  
  storage_account_name = "versionedstorage001"
  resource_group       = "rg-data"
  
  blob_properties = {
    versioning_enabled = true
    change_feed_enabled = true
    
    delete_retention_policy = {
      days = 30
    }
    
    container_delete_retention_policy = {
      days = 7
    }
    
    cors_rule = [
      {
        allowed_headers    = ["*"]
        allowed_methods    = ["GET", "POST"]
        allowed_origins    = ["https://myapp.example.com"]
        exposed_headers    = ["*"]
        max_age_in_seconds = 3600
      }
    ]
  }
}
```

### Premium Storage for High Performance

```hcl
module "premium_storage" {
  source = "../modules/storage/storage_account"
  
  storage_account_name     = "premiumstorage001"
  resource_group          = "rg-performance"
  account_tier           = "Premium"
  account_kind           = "BlockBlobStorage"
  account_replication_type = "LRS"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `storage_account_name` | Storage account name | `string` | n/a | yes |
| `resource_group` | Resource group (object) or name (string) | `any` | n/a | yes |
| `location` | Azure region | `string` | `"eastus2"` | no |
| `account_tier` | Storage account tier | `string` | `"Standard"` | no |
| `account_replication_type` | Replication type | `string` | `"LRS"` | no |
| `account_kind` | Storage account kind | `string` | `"StorageV2"` | no |
| `access_tier` | Access tier | `string` | `"Hot"` | no |
| `min_tls_version` | Minimum TLS version | `string` | `"TLS1_2"` | no |
| `allow_nested_items_to_be_public` | Allow public blobs | `bool` | `false` | no |
| `shared_access_key_enabled` | Enable access keys | `bool` | `true` | no |
| `public_network_access_enabled` | Enable public access | `bool` | `true` | no |
| `network_rules` | Network access rules | `object` | `{}` | no |
| `blob_properties` | Blob service properties | `object` | `{}` | no |
| `containers` | Containers to create | `list(object)` | `[]` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |
| `purpose` | Storage purpose (for tagging) | `string` | `"general"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `storage_account` | Complete storage account object |
| `storage_account_id` | Storage account ID |
| `storage_account_name` | Storage account name |
| `primary_blob_endpoint` | Primary blob endpoint |
| `primary_access_key` | Primary access key (sensitive) |
| `primary_connection_string` | Primary connection string (sensitive) |
| `containers` | Created containers |

## Security Features

- **HTTPS enforced**: HTTPS-only traffic is the service default
- **Modern TLS**: Minimum TLS 1.2 by default
- **No public blob access**: `allow_nested_items_to_be_public = false`
- **Network restrictions**: Support for IP rules and VNet integration
- **Access key management**: Optional access key disabling

## Best Practices

1. **Naming**: Use descriptive names with environment/purpose suffix
2. **Replication**: Choose appropriate replication for your durability needs
3. **Access tiers**: Use "Cool" for infrequently accessed data
4. **Network security**: Implement network rules for production workloads
5. **Retention policies**: Configure appropriate retention for compliance
6. **Monitoring**: Use tags consistently for cost allocation and monitoring

## Storage Account Naming

Storage account names must be:

- 3-24 characters long
- Lowercase letters and numbers only
- Globally unique across Azure

## Examples by Use Case

### Function App Storage

```hcl
storage_account_name = "myappfunc001"
purpose = "function_app"
containers = [
  { name = "azure-webjobs-hosts" },
  { name = "azure-webjobs-secrets" }
]
```

### Data Lake Storage

```hcl
account_kind = "StorageV2"
is_hns_enabled = true  # Hierarchical namespace for Data Lake
purpose = "data_lake"
```

### Static Website Hosting

```hcl
static_website = {
  index_document = "index.html"
  error_404_document = "404.html"
}
purpose = "static_website"
```
