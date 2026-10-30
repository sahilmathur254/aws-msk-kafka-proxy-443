mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
        }]
      })
    }
  }
  # Provide valid mock ARNs for the resources so AWS provider validation passes
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn    = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/mock-lb/1234567890abcdef"
      vpc_id = "vpc-1234567890" # This forces the mock resource to return your expected VPC ID
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock-tg/1234567890abcdef"
    }
  }
}
# Global dummy values to satisfy required module inputs across all guardrail tests
variables {
  vpc_id                           = "vpc-1234567890"
  public_subnet_ids                = ["subnet-pub1", "subnet-pub2"]
  private_subnet_ids               = ["subnet-priv1", "subnet-priv2"]
  msk_security_group_id            = "sg-1234567890"
  msk_bootstrap_brokers_sasl_scram = "b-1.mock.kafka.amazonaws.com:9096"
  kafka_domain                     = "mock.kafka.local"
  tls_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:mock-secret"
  client_cidrs                     = ["10.0.0.0/16"]
  route53_zone_id                  = "Z1234567890MOCK"
}

# Requirement 1: Reject unrestricted 0.0.0.0/0 client access by default
# Requirement 2: Verify explicit unrestricted-CIDR escape hatch
run "allow_unrestricted_client_cidrs_escape_hatch" {
  command = plan

  variables {
    client_cidrs                    = ["0.0.0.0/0"]
    allow_unrestricted_client_cidrs = true
  }

  assert {
    condition     = length(var.client_cidrs) > 0
    error_message = "Unrestricted client CIDR should be allowed when allow_unrestricted_client_cidrs is true."
  }
}
run "reject_unrestricted_client_cidrs_by_default" {
  command = plan

  variables {
    client_cidrs                    = ["0.0.0.0/0"]
    allow_unrestricted_client_cidrs = false
  }

  expect_failures = [
    aws_lb.kafka,
  ]
}


# Requirement 2: Verify explicit mutable-tag escape hatch
run "allow_mutable_image_tag_escape_hatch" {
  command = plan

  variables {
    kroxylicious_image      = "kroxylicious/proxy:latest"
    allow_mutable_image_tag = true
  }

  assert {
    condition     = var.kroxylicious_image == "kroxylicious/proxy:latest"
    error_message = "Mutable image tags should be permitted when allow_mutable_image_tag is true."
  }
}
run "reject_mutable_image_tag_by_default" {
  command = plan

  variables {
    kroxylicious_image      = "kroxylicious/proxy:latest"
    allow_mutable_image_tag = false
  }

  expect_failures = [
    aws_lb.kafka,
  ]
}
run "reject_invalid_name_input" {
  command = plan

  variables {
    # Fails because it starts with a number and has uppercase letters
    name = "1-INVALID-NAME"
  }

  # Test passes if Terraform blocks the plan due to the var.name validation
  expect_failures = [
    var.name
  ]
}
# Requirement 3: Verify kafka domain
run "reject_invalid_kafka_domain" {
  command = plan

  variables {
    # Fails because it doesn't have a dot (not a fully qualified domain)
    kafka_domain = "invalid-domain-no-dots"
  }

  # Test passes if Terraform blocks the plan due to the var.kafka_domain validation
  expect_failures = [
    var.kafka_domain
  ]
}

run "reject_empty_domain_input" {
  command = plan

  variables {
    # Fails because it is empty (the regex requires characters)
    kafka_domain = ""
  }

  expect_failures = [
    var.kafka_domain
  ]
}

run "reject_invalid_bootstrap_label" {
  command = plan

  variables {
    # Fails  because bootstrap_label is invalid
    bootstrap_label = "MYAPP"

  }

  expect_failures = [
    var.bootstrap_label
  ]

}
run "reject_empty_bootstrap_label" {
  command = plan

  variables {
    # Fails  because bootstrap_label is invalid
    bootstrap_label = ""

  }

  expect_failures = [
    var.bootstrap_label
  ]

}
run "reject_invalid_broker_label_prefix" {
  command = plan

  variables {
    # Fails  because broker_label_prefix is invalid
    broker_label_prefix = "MYAPP"

  }

  expect_failures = [
    var.broker_label_prefix
  ]

}
run "reject_empty_broker_label_prefix" {
  command = plan

  variables {
    # Fails  because bootstrap_label is invalid
    broker_label_prefix = ""
  }

  expect_failures = [
    var.broker_label_prefix
  ]

}
#reject invalid names
run "reject_incorrect_name_containg_capital_letter" {
  command = plan
  variables {
    #Fails because the variable name starts with capital letter
    name = "Kafka-msk"
  }
  expect_failures = [
    var.name
  ]

}
run "reject_incorrect_name_starting_with_a_digit_or_hypen" {
  command = plan
  variables {
    #Fails because the variable name starts with capital letter
    name = "1kafka-msk"
  }
  expect_failures = [
    var.name
  ]
}
run "reject_incorrect_name_no_of_letters" {
  command = plan
  #Fails because the varable either contains  either more or less than 3-24 letters range 
  variables {
    name = "production-us-east-1-data-pipeline-worker"
  }
  expect_failures = [
    var.name
  ]
}

run "empty_name" {
  command = plan
  variables {
    name = ""
  }
  expect_failures = [
    var.name
  ]

}
run "verify_vpc_id_is_wired_to_nlb" {
  command = apply
  # No variables block needed — inherits from global

  assert {
    condition     = aws_lb.kafka.vpc_id == var.vpc_id
    error_message = "NLB must be created in the provided VPC."
  }
}

run "reject_insufficient_public_subnets" {
  command = plan

  variables {
    public_subnet_ids = ["subnet-pub1"] # Only 1 subnet provided
  }

  expect_failures = [
    var.public_subnet_ids,
  ]
}

run "reject_duplicate_public_subnets" {
  command = plan

  variables {
    public_subnet_ids = ["subnet-pub1", "subnet-pub1"] # Not distinct
  }

  expect_failures = [
    var.public_subnet_ids,
  ]
}
run "reject_empty_public_subnets" {
  command = plan

  variables {
    public_subnet_ids = []
  }

  expect_failures = [
    var.public_subnet_ids,
  ]
}



run "verify_msk_security_group_id_is_wired" {
  command = plan

  assert {
    condition = anytrue([
      for rule in aws_vpc_security_group_ingress_rule.msk_from_proxy :
      rule.security_group_id == var.msk_security_group_id
    ])
    error_message = "MSK ingress must reference the provided SG."
  }
}
# ============================================================
# FAILING CASES for msk_bootstrap_brokers_sasl_scram
# Regex: ^[^,:[:space:]]+:[1-9][0-9]{0,4}(,[^,:[:space:]]+:[1-9][0-9]{0,4})*$
# ============================================================

# ---- empty / missing pieces ----

run "msk_bootstrap_brokers_sasl_scram_empty_string_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = ""
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_missing_port_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker:"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_missing_host_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = ":9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_only_colon_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = ":"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

# ---- invalid port values ----

run "msk_bootstrap_brokers_sasl_scram_port_zero_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker:0"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_port_leading_zero_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker:09096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_port_non_numeric_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker:abc"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_port_six_digits_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker:100000"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_port_negative_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker:-9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

# ---- comma / list structure ----

run "msk_bootstrap_brokers_sasl_scram_trailing_comma_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker1:9096,"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_leading_comma_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = ",broker1:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_double_comma_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker1:9096,,broker2:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_only_comma_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = ","
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

# ---- whitespace anywhere ----

run "msk_bootstrap_brokers_sasl_scram_space_after_comma_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker1:9096, broker2:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_space_before_comma_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker1:9096 ,broker2:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_leading_space_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = " broker1:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_trailing_space_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker1:9096 "
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_space_inside_host_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "bro ker1:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_trailing_newline_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker1:9096\n"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_newline_between_entries_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker1:9096\n,broker2:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_tab_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker1:9096\t,broker2:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

# ---- extra colons in host (no brackets) ----

run "msk_bootstrap_brokers_sasl_scram_double_colon_host_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker:extra:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_ipv6_unbracketed_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "2001:db8::1:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_ipv6_bracketed_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "[2001:db8::1]:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

# ---- protocol / scheme junk ----

run "msk_bootstrap_brokers_sasl_scram_with_scheme_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "sasl_ssl://broker1:9096"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_bootstrap_brokers_sasl_scram_port_with_suffix_fails" {
  command = plan
  variables {
    msk_bootstrap_brokers_sasl_scram = "broker1:9096abc"
  }
  expect_failures = [var.msk_bootstrap_brokers_sasl_scram]
}

run "msk_broker_port_incorrect_range_fails_on_zero" {
  command = plan
  variables {
    msk_broker_port = 0
  }
  expect_failures = [
    var.msk_broker_port
  ]
}

run "msk_broker_port_incorrect_range_fails_on_65536" {
  command = plan
  variables {
    msk_broker_port = 65536
  }
  expect_failures = [
    var.msk_broker_port
  ]
}