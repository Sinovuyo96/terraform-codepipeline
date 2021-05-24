provider "aws" {
  profile = "terraform"
  region  = "us-east-1"
}

resource "aws_codecommit_repository" "sinovuyo" {
  repository_name = "sinovuyo_pipeline"
  description     = "This is the Sample App Repository"
}

resource "aws_codepipeline" "codepipeline" {
  name     = "sinovuyo-test-pipeline"
  role_arn = aws_iam_role.codepipeline_role123.arn

  artifact_store {
    location = "sinov-pipeline-bucket"
    type     = "S3"

    # encryption_key {
    #   id   = data.aws_kms_alias.s3kmskey.arn
    #   type = "KMS"
    # }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      # role_arn = aws_iam_role.codepipeline_role.arn
      configuration = {
        # ConnectionArn    = aws_codestarconnections_connection.example.arn
        RepositoryName = aws_codecommit_repository.sinovuyo.repository_name
        BranchName     = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.sno_project_plan.name
      }
    }
  }
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "sinov-pipeline-bucket"
  acl    = "public-read-write"
}

# state bucket

resource "aws_s3_bucket" "state-bucket" {
  bucket = "sinovuyo-state-bucket"
  acl    = "public-read-write"
}

# CodePipeline
resource "aws_iam_role" "codepipeline_role123" {
  name = "sinovuyo-pipeline-role1"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


#  CodePipeline Policy

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role123.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
  "Action": [  
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:UploadArchive",
      "codecommit:GetUploadArchiveStatus",      
      "codecommit:CancelUploadArchive",
      "codecommit:BatchGet*",
      "codecommit:BatchDescribe*",
      "codecommit:Describe*",
      "codecommit:EvaluatePullRequestApprovalRules",
      "codecommit:Get*",
      "codecommit:List*",
      "codecommit:GitPull",
      "codecommit:UploadArchive"
            ],
  "Resource": "*",
  "Effect": "Allow"
},
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# CodeBuild
resource "aws_iam_role" "codebuild_role123" {
  name = "codebuild1"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "build-policy" {
  role = aws_iam_role.codebuild_role123.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
     {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "ec2:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
         "${aws_s3_bucket.codepipeline_bucket.arn}/*",
         "${aws_s3_bucket.state-bucket.arn}",
         "${aws_s3_bucket.state-bucket.arn}/*"
      ]
    }
  ]
 }
POLICY
}
# CodeBuild
# codebuild

resource "aws_codebuild_project" "sno_project_plan" {
  name          = "codebuild-project"
  description   = "Terraform codebuild project"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild_role123.arn

  # artifacts {
  #   type = "CODEPIPELINE"
  # }

  artifacts {
    type     = "S3"
    location = aws_s3_bucket.codepipeline_bucket.arn
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TERRAFORM_VERSION"
      value = "0.12.16"
    }
  }


  source {
    type     = "CODECOMMIT"
    location = aws_codecommit_repository.sinovuyo.repository_name
    # buildspec = "buildspec.yml"
  }

  tags = {
    Terraform = "true"
  }
}

# Role for state bucket
output "codebuild_terraform_plan_name" {
  value = aws_codebuild_project.sno_project_plan.arn
}

resource "aws_iam_role" "state_role123" {
  name = "sino-state-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


#  CodePipeline Policy for state bucket

resource "aws_iam_role_policy" "state_policy" {
  name = "codepipeline_policy-state"
  role = aws_iam_role.state_role123.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.state-bucket.arn}",
        "${aws_s3_bucket.state-bucket.arn}/*"
      ]
    },
    {
  "Action": [  
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:UploadArchive",
      "codecommit:GetUploadArchiveStatus",      
      "codecommit:CancelUploadArchive"
            ],
  "Resource": "*",
  "Effect": "Allow"
},
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
