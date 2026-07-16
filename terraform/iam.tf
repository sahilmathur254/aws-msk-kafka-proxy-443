data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution_base" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_tls_secret" {
  name = "read-proxy-tls-secret"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "ReadOnlyConfiguredTlsSecret"
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = [var.tls_secret_arn]
        }
      ],
      var.tls_secret_kms_key_arn == null ? [] : [
        {
          Sid      = "DecryptConfiguredTlsSecret"
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = [var.tls_secret_kms_key_arn]
        }
      ]
    )
  })
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags               = local.common_tags
}
