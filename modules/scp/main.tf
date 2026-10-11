locals {
  # Principals that may bypass guardrails (break-glass / automation roles).
  exempt_condition = length(var.exempt_principal_arns) == 0 ? {} : {
    ArnNotLike = { "aws:PrincipalArn" = var.exempt_principal_arns }
  }

  # Global services that must stay reachable regardless of the region allowlist.
  global_service_actions = [
    "a4b:*", "access-analyzer:*", "account:*", "acm:*", "aws-marketplace-management:*",
    "aws-marketplace:*", "aws-portal:*", "budgets:*", "ce:*", "chime:*", "cloudfront:*",
    "config:*", "cur:*", "directconnect:*", "ec2:DescribeRegions", "ec2:DescribeTransitGateways",
    "ec2:DescribeVpnGateways", "fms:*", "globalaccelerator:*", "health:*", "iam:*",
    "importexport:*", "kms:*", "mobileanalytics:*", "networkmanager:*", "organizations:*",
    "pricing:*", "route53:*", "route53domains:*", "route53-recovery-cluster:*",
    "route53-recovery-control-config:*", "route53-recovery-readiness:*", "s3:GetAccountPublic*",
    "s3:ListAllMyBuckets", "s3:ListMultiRegionAccessPoints", "s3:PutAccountPublic*", "shield:*",
    "sso:*", "sts:*", "support:*", "trustedadvisor:*", "waf-regional:*", "waf:*", "wafv2:*",
    "wellarchitected:*",
  ]

  policies = {
    deny_leave_organization = {
      description = "Member accounts cannot leave the organization."
      content = {
        Version = "2012-10-17"
        Statement = [{
          Sid      = "DenyLeaveOrganization"
          Effect   = "Deny"
          Action   = ["organizations:LeaveOrganization"]
          Resource = "*"
        }]
      }
    }

    deny_root_user = {
      description = "Block all actions by member-account root users."
      content = {
        Version = "2012-10-17"
        Statement = [{
          Sid       = "DenyRootUser"
          Effect    = "Deny"
          Action    = "*"
          Resource  = "*"
          Condition = { ArnLike = { "aws:PrincipalArn" = ["arn:aws:iam::*:root"] } }
        }]
      }
    }

    region_allowlist = {
      description = "Deny regional actions outside the approved regions."
      content = {
        Version = "2012-10-17"
        Statement = [{
          Sid       = "DenyOutsideAllowedRegions"
          Effect    = "Deny"
          NotAction = local.global_service_actions
          Resource  = "*"
          Condition = merge(
            { StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions } },
            local.exempt_condition,
          )
        }]
      }
    }

    protect_security_services = {
      description = "Stop anyone disabling CloudTrail, Config, GuardDuty, Security Hub or Access Analyzer."
      content = {
        Version = "2012-10-17"
        Statement = [merge({
          Sid    = "ProtectSecurityServices"
          Effect = "Deny"
          Action = [
            "cloudtrail:DeleteTrail", "cloudtrail:StopLogging", "cloudtrail:UpdateTrail", "cloudtrail:PutEventSelectors",
            "config:DeleteConfigurationRecorder", "config:DeleteDeliveryChannel", "config:StopConfigurationRecorder",
            "guardduty:DeleteDetector", "guardduty:DisassociateFromMasterAccount", "guardduty:DisassociateFromAdministratorAccount", "guardduty:UpdateDetector",
            "securityhub:DisableSecurityHub", "securityhub:DisassociateFromMasterAccount", "securityhub:DisassociateFromAdministratorAccount",
            "access-analyzer:DeleteAnalyzer",
          ]
          Resource = "*"
          # Omit Condition entirely when there are no exemptions: AWS rejects "Condition": null.
        }, length(local.exempt_condition) == 0 ? {} : { Condition = local.exempt_condition })]
      }
    }

    require_imdsv2 = {
      description = "EC2 instances must be launched with IMDSv2 (session tokens) required."
      content = {
        Version = "2012-10-17"
        Statement = [{
          Sid       = "RequireImdsV2"
          Effect    = "Deny"
          Action    = "ec2:RunInstances"
          Resource  = "arn:aws:ec2:*:*:instance/*"
          Condition = { StringNotEquals = { "ec2:MetadataHttpTokens" = "required" } }
        }]
      }
    }
  }

  enabled = { for k, p in local.policies : k => p if contains(keys(var.attachments), k) }

  # Flatten {policy => [targets]} into one attachment per pair.
  # Keys use static labels (not IDs) so plans work before OUs/accounts exist.
  attachment_pairs = merge([
    for policy, targets in var.attachments : {
      for label, target_id in targets : "${policy}:${label}" => { policy = policy, target = target_id }
    } if contains(keys(local.policies), policy)
  ]...)
}

resource "aws_organizations_policy" "this" {
  for_each = local.enabled

  name        = "${var.name_prefix}-${replace(each.key, "_", "-")}"
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(each.value.content)
  tags        = var.tags
}

resource "aws_organizations_policy_attachment" "this" {
  for_each = local.attachment_pairs

  policy_id = aws_organizations_policy.this[each.value.policy].id
  target_id = each.value.target
}
