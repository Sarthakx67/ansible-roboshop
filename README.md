# Terraform ALB + Auto Scaling Module - Complete Guide

A comprehensive guide covering AWS Application Load Balancer, Auto Scaling Groups, and Target Groups with complete theoretical knowledge and Terraform implementation.

## Table of Contents
1. [Overview](#overview)
2. [AWS Concepts & Theory](#aws-concepts--theory)
3. [Module Architecture](#module-architecture)
4. [Resource Details](#resource-details)
5. [Variables Explained](#variables-explained)
6. [Best Practices](#best-practices)
7. [Common Use Cases](#common-use-cases)

---

## Overview

This Terraform module creates a complete **auto-scaling infrastructure** with:
- **Target Group** for routing traffic
- **Launch Template** for EC2 instance configuration
- **Auto Scaling Group** for elasticity
- **Auto Scaling Policy** for CPU-based scaling
- **Load Balancer Listener Rule** for traffic routing

**Purpose**: Automatically scale your application based on demand while maintaining high availability.

---

## AWS Concepts & Theory

### 1. Application Load Balancer (ALB)

**What is it?**
An Application Load Balancer operates at Layer 7 (Application Layer) of the OSI model and intelligently distributes incoming HTTP/HTTPS traffic across multiple targets (EC2 instances, containers, IP addresses).

**Key Features:**
- **Content-based routing**: Routes traffic based on URL path, host headers, HTTP methods
- **Host-based routing**: Different domains → different target groups
- **Path-based routing**: Different URLs → different target groups
- **Health checks**: Automatically detects unhealthy targets
- **SSL/TLS termination**: Handles HTTPS encryption/decryption
- **WebSocket support**: Persistent connections
- **HTTP/2 support**: Improved performance

**How it works:**
```
User Request → ALB → Listener → Rules → Target Group → Healthy Instances
```

**Components:**
1. **Load Balancer**: The main resource that receives traffic
2. **Listener**: Checks for connection requests (port 80, 443)
3. **Rules**: Determines how to route requests (host/path-based)
4. **Target Group**: Collection of targets receiving traffic

---

### 2. Target Group

**What is it?**
A logical grouping of targets (EC2 instances) that receive traffic from the load balancer. The load balancer routes requests to registered targets based on the configured rules.

**Key Concepts:**

**Target Types:**
- **Instance**: Route to EC2 instance IDs
- **IP**: Route to IP addresses
- **Lambda**: Route to Lambda functions
- **ALB**: Route to another ALB

**Health Checks:**
Health checks determine if a target is healthy and can receive traffic.

**Health Check Parameters:**
- **Protocol**: HTTP, HTTPS, TCP
- **Port**: Port to check (e.g., 8080)
- **Path**: URL path to check (e.g., /health)
- **Interval**: Time between checks (seconds)
- **Timeout**: Time to wait for response
- **Healthy threshold**: Consecutive successes needed
- **Unhealthy threshold**: Consecutive failures needed
- **Matcher**: Expected HTTP response codes (200-299)

**Health Check Flow:**
```
Target Group → Health Check → Instance
                    ↓
            200 OK (Healthy)
            Timeout/5xx (Unhealthy)
```

**Registration:**
- Manual: Register instances manually
- Auto Scaling: Instances auto-register/deregister

**Deregistration Delay:**
Time to wait before removing a target (default: 300s) - allows in-flight requests to complete.

---

### 3. Launch Template

**What is it?**
A blueprint/template that defines the configuration for EC2 instances. It's the modern replacement for Launch Configurations.

**Why Use Launch Templates?**
- **Versioning**: Create multiple versions, rollback if needed
- **Source templates**: Copy existing templates
- **Mix instance types**: Use multiple instance types in Auto Scaling
- **Spot instances**: Define Spot instance parameters
- **T2/T3 Unlimited**: Configure CPU credits
- **Latest features**: Access newest EC2 features

**Launch Template vs Launch Configuration:**
| Feature | Launch Template | Launch Configuration |
|---------|----------------|---------------------|
| Versioning | ✅ Yes | ❌ No |
| Multiple Instance Types | ✅ Yes | ❌ No |
| Spot + On-Demand Mix | ✅ Yes | ❌ No |
| Latest Features | ✅ Always | ❌ Limited |
| Recommended | ✅ Yes | ❌ Deprecated |

**Key Components:**
- **AMI ID**: Which image to use
- **Instance Type**: t2.micro, t3.medium, etc.
- **Key Pair**: SSH access
- **Security Groups**: Firewall rules
- **User Data**: Bootstrap script
- **IAM Role**: Permissions for the instance
- **Storage**: EBS volume configuration
- **Network Interfaces**: VPC, subnet settings
- **Tags**: Metadata for organization

**Instance Initiated Shutdown Behavior:**
- **stop**: Instance stops (can be restarted)
- **terminate**: Instance terminates (cannot be restarted)
- For Auto Scaling: Always use `terminate`

---

### 4. Auto Scaling Group (ASG)

**What is it?**
Automatically adjusts the number of EC2 instances based on demand, ensuring application availability and optimizing costs.

**Core Concepts:**

**Desired Capacity:**
The number of instances you want running at any time.
- ASG maintains this count
- Can be changed manually or by scaling policies

**Min/Max Size:**
- **Min**: Minimum instances (never go below)
- **Max**: Maximum instances (never exceed)
- **Example**: Min=1, Desired=2, Max=4

**Scaling Actions:**
1. **Scale Out**: Add instances (demand increases)
2. **Scale In**: Remove instances (demand decreases)

**Health Checks:**
Determines if instances are healthy:
- **EC2 Health Check**: Instance running state
- **ELB Health Check**: Load balancer health checks (recommended)

**Health Check Grace Period:**
Time to wait before checking instance health (allows startup time).
- Default: 300 seconds
- Gives instance time to initialize and become healthy

**Availability Zones (AZ):**
ASG distributes instances across multiple AZs for high availability.
- **VPC Zone Identifier**: Subnets where instances launch
- Best practice: Use subnets in different AZs

**Lifecycle:**
```
Launch → InService → Healthy
                    ↓ (if unhealthy)
                Terminating → New Instance Launch
```

**Termination Policies:**
When scaling in, which instance to terminate?
- **Default**: Balance across AZs, then oldest launch template
- **OldestInstance**: Terminate oldest instance
- **NewestInstance**: Terminate newest instance
- **OldestLaunchConfiguration**: Oldest launch config
- **ClosestToNextInstanceHour**: Save costs

**Benefits:**
- ✅ High availability across AZs
- ✅ Automatic health replacement
- ✅ Cost optimization (scale in when not needed)
- ✅ Integration with ELB/ALB
- ✅ Scheduled scaling
- ✅ Predictive scaling

---

### 5. Auto Scaling Policies

**What is it?**
Rules that define when and how to scale your Auto Scaling Group.

**Types of Scaling Policies:**

#### 1. Target Tracking Scaling (Used in this module)
**Concept**: Maintain a specific metric at a target value (like a thermostat).

**How it works:**
```
Current CPU: 80%
Target CPU: 70%
Action: Add instances to reduce load
```

**Predefined Metrics:**
- **ASGAverageCPUUtilization**: Average CPU across all instances
- **ASGAverageNetworkIn**: Network bytes in
- **ASGAverageNetworkOut**: Network bytes out
- **ALBRequestCountPerTarget**: Requests per instance

**Custom Metrics:**
You can use CloudWatch custom metrics (e.g., queue length, active connections).

**Advantages:**
- ✅ Simple to configure
- ✅ Automatically creates scale-out and scale-in policies
- ✅ Adapts to changing patterns

**Example:**
Target CPU = 70%
- If avg CPU > 70% → Add instances
- If avg CPU < 70% → Remove instances

#### 2. Step Scaling
Scale based on CloudWatch alarm thresholds with different step adjustments.

**Example:**
- CPU 50-60%: Add 1 instance
- CPU 60-80%: Add 2 instances
- CPU > 80%: Add 3 instances

#### 3. Simple Scaling
Single scaling action based on CloudWatch alarm.

**Example:**
- If CPU > 70%: Add 1 instance

#### 4. Scheduled Scaling
Scale based on time/date.

**Example:**
- Monday-Friday 9 AM: Set desired capacity to 10
- Monday-Friday 6 PM: Set desired capacity to 2

#### 5. Predictive Scaling
Uses machine learning to predict future traffic and scale proactively.

**Cooldown Period:**
Time to wait between scaling activities (prevents thrashing).
- Scale out: Immediate (no cooldown)
- Scale in: Default 300s cooldown

---

### 6. Load Balancer Listener & Rules

**Listener:**
Checks for connection requests from clients using the protocol and port you configure.

**Common Listeners:**
- HTTP (Port 80)
- HTTPS (Port 443)

**Listener Rules:**
Determine how requests are routed to target groups.

**Rule Components:**
1. **Priority**: Lower number = higher priority (1 is highest)
2. **Conditions**: When to apply the rule
3. **Actions**: What to do with the request

**Conditions (Types):**
- **Host header**: Based on domain name
  - `api.example.com` → API target group
  - `web.example.com` → Web target group
- **Path pattern**: Based on URL path
  - `/api/*` → API target group
  - `/images/*` → Static content target group
- **HTTP headers**: Based on custom headers
- **Query string**: Based on query parameters
- **Source IP**: Based on client IP

**Actions (Types):**
- **Forward**: Send to target group
- **Redirect**: Redirect to different URL
- **Fixed response**: Return fixed HTTP response
- **Authenticate**: Authenticate via OIDC/Cognito

**Example Flow:**
```
Request: https://api.example.com/users
         ↓
Listener (Port 443)
         ↓
Rule (Priority 10): host_header = "api.example.com"
         ↓
Action: Forward to API Target Group
         ↓
API Target Group
         ↓
Healthy EC2 Instances
```

**Default Rule:**
Every listener has a default rule (lowest priority) that forwards to a default target group if no other rules match.

---

## Module Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Load Balancer                 │
│                                                               │
│  ┌─────────────┐         ┌──────────────────────────────┐  │
│  │  Listener   │────────▶│   Listener Rule              │  │
│  │  (Port 80)  │         │   (host_header condition)    │  │
│  └─────────────┘         └──────────────────────────────┘  │
│                                     │                         │
└─────────────────────────────────────┼─────────────────────────┘
                                      │
                                      ▼
                          ┌──────────────────────┐
                          │   Target Group       │
                          │   (Port 8080)        │
                          │   Health Check: /health │
                          └──────────────────────┘
                                      │
                                      ▼
                          ┌──────────────────────┐
                          │ Auto Scaling Group   │
                          │ Min: 1, Max: 4       │
                          │ Desired: 1           │
                          └──────────────────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
              ┌──────────┐      ┌──────────┐     ┌──────────┐
              │ Instance │      │ Instance │     │ Instance │
              │    1     │      │    2     │     │    3     │
              └──────────┘      └──────────┘     └──────────┘
                    ▲                 ▲                 ▲
                    └─────────────────┴─────────────────┘
                              Launch Template
                         (AMI, Instance Type, User Data)
```

### Scaling Behavior

```
Normal Load (CPU < 70%):
├── Desired Capacity: 1
├── Running Instances: 1
└── Status: Stable

High Load (CPU > 70%):
├── Auto Scaling Policy Triggered
├── Add Instances (scale out)
├── Desired Capacity: 1 → 2 → 3
├── New Instances: Launch from template
├── Registration: Auto-register to target group
└── Health Check: Wait for healthy status

Low Load (CPU < 70% for duration):
├── Auto Scaling Policy Triggered
├── Remove Instances (scale in)
├── Desired Capacity: 3 → 2 → 1
├── Deregistration: Remove from target group
├── Connection Draining: Wait for in-flight requests
└── Termination: Terminate instances
```

---

## Resource Details

### 1. Target Group Resource (`aws_lb_target_group`)

**Purpose**: Creates the target group for the ALB to route traffic to.

**Key Attributes:**
```hcl
name     = "${var.project_name}-${var.common_tags.Component}"
port     = 8080                    # Application listens on this port
protocol = "HTTP"                  # HTTP or HTTPS
vpc_id   = var.vpc_id              # VPC where targets reside
```

**Health Check Configuration:**
```hcl
health_check {
  enabled             = true        # Enable health checks
  healthy_threshold   = 2          # 2 consecutive successes = healthy
  unhealthy_threshold = 3          # 3 consecutive failures = unhealthy
  interval            = 15         # Check every 15 seconds
  timeout             = 5          # Wait 5 seconds for response
  path                = "/health"  # URL endpoint to check
  port                = 8080       # Port to check
  protocol            = "HTTP"     # Protocol to use
  matcher             = "200-299"  # Expected HTTP response codes
}
```

**Health Check Logic:**
```
Instance Status: Unknown
↓
Health Check 1: 200 OK (1/2 healthy)
↓
Health Check 2: 200 OK (2/2 healthy) ✓
↓
Instance Status: Healthy → Receives Traffic
```

---

### 2. Launch Template Resource (`aws_launch_template`)

**Purpose**: Defines the configuration for EC2 instances launched by Auto Scaling.

**Key Attributes:**
```hcl
name       = "${var.project_name}-${var.common_tags.Component}"
image_id   = var.image_id                              # AMI to use
instance_type = var.instance_type                      # t2.micro, t3.medium, etc.
key_name   = var.key_name                              # SSH key pair
instance_initiated_shutdown_behavior = "terminate"     # Stop vs Terminate
vpc_security_group_ids = [var.security_group_id]       # Firewall rules
user_data  = var.user_data                             # Bootstrap script
```

**Dynamic Tag Specifications:**
Tags can be applied to different resource types:
- `instance`: The EC2 instance itself
- `volume`: EBS volumes attached to instance
- `network-interface`: ENI attached to instance

**Example:**
```hcl
launch_template_tags = [
  {
    resource_type = "instance"
    tags = {
      Name = "web-server"
      Environment = "production"
    }
  },
  {
    resource_type = "volume"
    tags = {
      Name = "web-server-volume"
    }
  }
]
```

**User Data:**
Script that runs when instance launches (cloud-init).

**Common uses:**
- Install packages
- Configure application
- Start services
- Register with external systems

**Example:**
```bash
#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx
```

---

### 3. Auto Scaling Group Resource (`aws_autoscaling_group`)

**Purpose**: Manages the lifecycle and scaling of EC2 instances.

**Key Attributes:**
```hcl
name                      = "${var.project_name}-${var.common_tags.Component}"
min_size                  = 1              # Minimum instances
max_size                  = 4              # Maximum instances
desired_capacity          = 1              # Target number of instances
health_check_grace_period = 300            # Wait 5 minutes before checking
health_check_type         = "ELB"          # Use load balancer health checks
target_group_arns         = [...]          # Register with target group(s)
vpc_zone_identifier       = [subnets]      # Subnets to launch in
```

**Launch Template Reference:**
```hcl
launch_template {
  id      = aws_launch_template.main.id
  version = "$Latest"  # Always use latest version
}
```

**Version Options:**
- `$Latest`: Always use the latest version
- `$Default`: Use the default version
- Specific version: Use version number (e.g., "1", "2")

**Dynamic Tags:**
Tags applied to instances launched by ASG.

**Tag Attributes:**
- `key`: Tag name
- `value`: Tag value
- `propagate_at_launch`: true/false (apply to instances?)

**Example:**
```hcl
tag = [
  {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true   # Apply to instances
  },
  {
    key                 = "Environment"
    value               = "production"
    propagate_at_launch = true
  }
]
```

**VPC Zone Identifier:**
List of subnet IDs where instances will launch.

**Best Practice:**
- Use subnets in multiple AZs for high availability
- Use private subnets for security
- Ensure subnets have internet access (NAT Gateway) if needed

---

### 4. Auto Scaling Policy Resource (`aws_autoscaling_policy`)

**Purpose**: Defines when and how to scale the Auto Scaling Group.

**Configuration:**
```hcl
autoscaling_group_name = aws_autoscaling_group.main.name
name                   = "cpu"
policy_type            = "TargetTrackingScaling"

target_tracking_configuration {
  predefined_metric_specification {
    predefined_metric_type = "ASGAverageCPUUtilization"
  }
  target_value = 70.0   # Maintain 70% CPU
}
```

**How Target Tracking Works:**

1. **Monitoring**: CloudWatch monitors average CPU across all instances
2. **Evaluation**: Compares current value to target value
3. **Decision**:
   - If current > target: Scale out (add instances)
   - If current < target: Scale in (remove instances)
4. **Action**: ASG adds/removes instances
5. **Wait**: Cooldown period before next evaluation

**Example Scenario:**
```
Time: 10:00 AM
Current State: 2 instances, CPU = 50%
Action: None (below target of 70%)

Time: 11:00 AM
Current State: 2 instances, CPU = 85%
Action: Scale out - add 1 instance

Time: 11:05 AM
Current State: 3 instances, CPU = 60%
Action: None (below target, wait for stabilization)

Time: 2:00 PM
Current State: 3 instances, CPU = 45%
Action: Scale in - remove 1 instance

Time: 2:05 PM
Current State: 2 instances, CPU = 65%
Action: None (stable)
```

**Scaling Calculations:**

**Scale Out (Add Instances):**
```
New Desired Capacity = Current Capacity + 
  CEILING((Current Metric - Target) / Target * Current Capacity)
```

**Example:**
- Current: 2 instances, CPU: 85%, Target: 70%
- Calculation: 2 + CEILING((85-70)/70 * 2) = 2 + CEILING(0.43) = 2 + 1 = 3

**Scale In (Remove Instances):**
More conservative to avoid oscillation. Waits for sustained low utilization.

---

### 5. Listener Rule Resource (`aws_lb_listener_rule`)

**Purpose**: Routes traffic from ALB listener to target group based on conditions.

**Configuration:**
```hcl
listener_arn = var.alb_listener_arn   # Which listener to attach to
priority     = var.rule_priority      # Lower = higher priority

action {
  type             = "forward"
  target_group_arn = aws_lb_target_group.main.arn
}

condition {
  host_header {
    values = [var.host_header]   # e.g., "api.example.com"
  }
}
```

**Priority System:**
Rules are evaluated in order of priority (1 = highest).

**Example:**
```
Priority 1: api.example.com → API Target Group
Priority 10: web.example.com → Web Target Group
Priority 100: *.example.com → Default Target Group
Default Rule: * → Fallback Target Group
```

**Request Flow:**
```
Request: https://api.example.com/users
↓
Check Rule Priority 1: api.example.com ✓ Match!
↓
Forward to API Target Group
↓
Route to healthy instance
```

**Multiple Conditions:**
You can combine conditions (AND logic):
```hcl
condition {
  host_header {
    values = ["api.example.com"]
  }
}

condition {
  path_pattern {
    values = ["/v1/*"]
  }
}
# Both conditions must match
```

---

## Variables Explained

### Essential Variables (Must Provide)

#### `project_name`
**Purpose**: Naming prefix for all resources  
**Example**: `"myapp"`  
**Usage**: Creates names like `myapp-web`, `myapp-api`

#### `env`
**Purpose**: Environment identifier  
**Example**: `"production"`, `"staging"`, `"dev"`  
**Usage**: Used in tags and naming

#### `common_tags`
**Purpose**: Tags applied to resources  
**Must Include**: `Component` key  
**Example**:
```hcl
common_tags = {
  Component   = "web"
  Environment = "production"
  ManagedBy   = "Terraform"
  Owner       = "devops-team"
}
```

#### `vpc_id`
**Purpose**: VPC where target group resides  
**Example**: `"vpc-0abc123def456"`  
**Note**: Must match VPC of subnets

#### `image_id`
**Purpose**: AMI ID for launching instances  
**Example**: `"ami-0abcdef1234567890"`  
**Tip**: Use AWS Systems Manager Parameter Store for latest AMIs

#### `security_group_id`
**Purpose**: Security group for instances  
**Example**: `"sg-0abc123def456"`  
**Must Allow**:
- Inbound: Port from ALB security group
- Outbound: Internet access (for updates)

#### `vpc_zone_identifier`
**Purpose**: List of subnet IDs for instance placement  
**Example**: `["subnet-abc123", "subnet-def456"]`  
**Best Practice**: Use subnets in multiple AZs

#### `alb_listener_arn`
**Purpose**: ARN of ALB listener to attach rule  
**Example**: `"arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/my-alb/..."`

#### `rule_priority`
**Purpose**: Priority of listener rule (1-50000)  
**Example**: `10`  
**Note**: Lower = higher priority, must be unique

#### `host_header`
**Purpose**: Domain name for routing  
**Example**: `"api.example.com"`  
**Supports**: Wildcards (`*.example.com`)

#### `key_name`
**Purpose**: EC2 key pair for SSH access  
**Example**: `"my-keypair"`  
**Note**: Must exist in the region

---

### Optional Variables (Have Defaults)

#### Health Check Configuration
```hcl
health_check = {
  enabled             = true        # Enable/disable health checks
  healthy_threshold   = 2          # Consecutive successes
  unhealthy_threshold = 3          # Consecutive failures
  interval            = 15         # Seconds between checks
  timeout             = 5          # Seconds to wait for response
  path                = "/health"  # URL to check
  port                = 8080       # Port to check (or "traffic-port")
  protocol            = "HTTP"     # HTTP or HTTPS
  matcher             = "200-299"  # Expected response codes
}
```

**Tuning Guidelines:**
- **Fast detection**: Lower interval (10s), lower thresholds (2/2)
- **Slow startup**: Higher grace period (600s), higher interval (30s)
- **Sensitive apps**: Higher healthy threshold (3), lower unhealthy threshold (2)

#### Target Group Settings
```hcl
target_group_port     = 8080      # Port where app listens
target_group_protocol = "HTTP"    # HTTP or HTTPS
```

#### Instance Configuration
```hcl
instance_type = "t2.micro"        # t2.micro, t3.medium, etc.
user_data     = ""                # Bootstrap script (base64 encoded)
```

**Instance Type Selection:**
| Type | vCPU | RAM | Use Case |
|------|------|-----|----------|
| t2.micro | 1 | 1 GB | Dev/Test |
| t2.small | 1 | 2 GB | Small apps |
| t3.medium | 2 | 4 GB | Production apps |
| t3.large | 2 | 8 GB | High memory apps |
| c5.large | 2 | 4 GB | CPU intensive |

#### Auto Scaling Configuration
```hcl
min_size                  = 1      # Minimum instances
max_size                  = 4      # Maximum instances
desired_capacity          = 1      # Initial count
health_check_grace_period = 300    # Seconds (5 minutes)
health_check_type         = "ELB"  # ELB or EC2
```

**Sizing Strategy:**
- **Min Size**: Set to minimum needed for availability (usually ≥2 for HA)
- **Max Size**: Set based on traffic predictions and budget
- **Desired Capacity**: Set to typical load

**Health Check Type:**
- `EC2`: Only checks if instance is running (basic)
- `ELB`: Checks application health via load balancer (recommended)

#### Auto Scaling Policy
```hcl
autoscaling_cpu_target = 70.0     # Target CPU percentage
```

**Target Value Guidelines:**
| Target | Behavior | Use Case |
|--------|----------|----------|
| 50% | Aggressive scaling | Cost-sensitive |
| 70% | Balanced | Recommended |
| 85% | Conservative | Performance-critical |

#### Tagging
```hcl
launch_template_tags = []   # Tags for instances, volumes, etc.
tag                  = []   # Tags for ASG and instances
```

---

## Best Practices

### 1. High Availability

**Multi-AZ Deployment:**
```hcl
vpc_zone_identifier = [
  "subnet-us-east-1a",   # AZ 1
  "subnet-us-east-1b",   # AZ 2
  "subnet-us-east-1c"    # AZ 3
]

min_size = 3   # At least one per AZ
```

**Benefits:**
- ✅ Survives AZ failure
- ✅ Load balanced across AZs
- ✅ Zero downtime deployments

### 2. Health Checks

**Application Health Endpoint:**
Create a dedicated `/health` endpoint that checks:
- Database connectivity
- Required services availability
- Disk space
- Memory usage

**Example (Node.js):**
```javascript
app.get('/health', async (req, res) => {
  try {
    await db.ping();  // Check database
    const memUsage = process.memoryUsage();
    if (memUsage.heapUsed / memUsage.heapTotal > 0.9) {
      throw new Error('High memory usage');
    }
    res.status(200).send('OK');
  } catch (error) {
    res.status(503).send('Service Unavailable');
  }
});
```

**Health Check Tuning:**
```hcl
# Fast detection for critical services
healthy_threshold   = 2
unhealthy_threshold = 2
interval           = 10

# Slow startup applications
health_check_grace_period = 600
```

### 3. Scaling Strategy

**Conservative Scaling:**
```hcl
min_size             = 2    # Always HA
max_size             = 10   # Budget limit
desired_capacity     = 2    # Start with min
autoscaling_cpu_target = 60.0  # Scale before saturation
```

**Cost-Optimized Scaling:**
```hcl
min_size             = 1    # Minimal cost
max_size             = 4    # Burst capability
desired_capacity     = 1
autoscaling_cpu_target = 80.0  # Tolerate higher load
```

### 4. Security

**Security Group Rules:**
```hcl
# Application security group
ingress {
  from_port       = 8080
  to_port         = 8080
  protocol        = "tcp"
  security_groups = [alb_security_group_id]  # Only from ALB
}

egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]  # Allow outbound
}
```

**Principle of Least Privilege:**
- ✅ Only allow traffic from ALB
- ✅ Use private subnets
- ✅ Use IAM roles for AWS API access
- ✅ Encrypt data in transit (HTTPS)

### 5. Cost Optimization

**Strategies:**
1. **Right-sizing**: Use appropriate instance types
2. **Scheduled Scaling**: Scale down during off-hours
3. **Spot Instances**: Mix with On-Demand (advanced)
4. **Reserved Instances**: For baseline capacity
5. **Monitoring**: Track unused capacity

**Example Scheduled Scaling:**
```hcl
# Business hours: 8 AM - 6 PM weekdays
resource "aws_autoscaling_schedule" "scale_up" {
  scheduled_action_name  = "scale-up"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 4
  recurrence            = "0 8 * * 1-5"  # 8 AM Mon-Fri
  autoscaling_group_name = aws_autoscaling_group.main.name
}

resource "aws_autoscaling_schedule" "scale_down" {
  scheduled_action_name  = "scale-down"
  min_size              = 1
  max_size              = 4
  desired_capacity      = 1
  recurrence            = "0 18 * * 1-5"  # 6 PM Mon-Fri
  autoscaling_group_name = aws_autoscaling_group.main.name
}
```

### 6. Monitoring & Alarms

**Essential CloudWatch Alarms:**

1. **High CPU Utilization**
```hcl
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "asg-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [sns_topic_arn]
}
```

2. **Unhealthy Hosts**
3. **Target Response Time**
4. **HTTP 5xx Errors**
5. **Network Traffic Anomalies**

**Key Metrics to Track:**
- `CPUUtilization`: Average CPU across ASG
- `NetworkIn/Out`: Network traffic
- `HealthyHostCount`: Number of healthy targets
- `UnHealthyHostCount`: Number of unhealthy targets
- `TargetResponseTime`: Application latency
- `RequestCount`: Total requests
- `HTTPCode_Target_5XX_Count`: Server errors

### 7. Deployment Strategy

**Blue-Green Deployment with ASG:**
1. Create new launch template version with updated AMI
2. Update ASG to use new version
3. ASG gradually replaces instances
4. Monitor health checks
5. Rollback if needed (revert to previous version)

**Rolling Updates:**
```hcl
# Update ASG configuration
min_size         = 2
max_size         = 6
desired_capacity = 4

# During update, ASG maintains capacity
# Terminates old instances one at a time
# Launches new instances with new configuration
```

### 8. Tagging Strategy

**Consistent Tagging:**
```hcl
common_tags = {
  Project     = "myapp"
  Environment = "production"
  Component   = "web"
  ManagedBy   = "Terraform"
  Owner       = "devops-team"
  CostCenter  = "engineering"
  Backup      = "daily"
}
```

**Benefits:**
- ✅ Cost allocation
- ✅ Resource organization
- ✅ Automation filtering
- ✅ Compliance tracking

---

## Common Use Cases

### Use Case 1: Web Application

**Scenario**: Hosting a web application that receives variable traffic throughout the day.

**Configuration:**
```hcl
project_name = "webapp"
common_tags = {
  Component = "web"
}

# Auto Scaling
min_size             = 2    # HA baseline
max_size             = 8    # Peak capacity
desired_capacity     = 2
autoscaling_cpu_target = 70.0

# Instance
instance_type = "t3.medium"
image_id      = "ami-webapp-v1.0"

# Health Check
health_check = {
  path     = "/health"
  interval = 30
  timeout  = 5
  healthy_threshold = 2
  unhealthy_threshold = 3
}

# Listener Rule
host_header   = "www.example.com"
rule_priority = 10
```

**Traffic Pattern:**
```
Morning (8 AM):  2 instances (low traffic)
Afternoon (1 PM): 5 instances (peak traffic)
Evening (8 PM):  2 instances (low traffic)
```

---

### Use Case 2: API Backend

**Scenario**: RESTful API with microservices architecture, handling varying request loads.

**Configuration:**
```hcl
project_name = "api"
common_tags = {
  Component = "api-gateway"
}

# Auto Scaling - More aggressive
min_size             = 3    # Multi-AZ HA
max_size             = 15   # High burst capacity
desired_capacity     = 3
autoscaling_cpu_target = 60.0  # Scale early

# Instance
instance_type = "c5.large"  # CPU optimized
image_id      = "ami-api-v2.1"

# Health Check - Fast detection
health_check = {
  path     = "/api/health"
  interval = 10
  timeout  = 5
  healthy_threshold = 2
  unhealthy_threshold = 2
  matcher = "200"
}

# Listener Rule - Path-based
host_header   = "api.example.com"
rule_priority = 5
```

**Benefits:**
- Fast scaling for API bursts
- CPU-optimized instances for compute
- Quick health detection for rapid failover

---

### Use Case 3: Background Workers

**Scenario**: Processing jobs from a queue (SQS, RabbitMQ), scaling based on queue depth.

**Configuration:**
```hcl
project_name = "worker"
common_tags = {
  Component = "queue-processor"
}

# Auto Scaling
min_size             = 1    # Cost-optimized
max_size             = 20   # Handle queue backlog
desired_capacity     = 2
# Note: Use custom CloudWatch metric for queue depth
# instead of CPU target tracking

# Instance
instance_type = "t3.large"  # Memory for batch processing
image_id      = "ami-worker-v1.5"

# Health Check - Simple
health_check = {
  path     = "/ready"  # Worker readiness check
  interval = 30
  timeout  = 10
  healthy_threshold = 2
  unhealthy_threshold = 5  # Tolerate processing spikes
}

# No ALB listener rule needed - workers pull from queue
```

**Scaling Metric**: Queue depth instead of CPU
```hcl
# Custom scaling policy based on SQS queue
resource "aws_autoscaling_policy" "queue_depth" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  name                   = "queue-depth"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"
    }
    target_value = 100.0  # 100 messages per instance
  }
}
```

---

### Use Case 4: Development Environment

**Scenario**: Cost-effective development environment with minimal resources.

**Configuration:**
```hcl
project_name = "myapp"
common_tags = {
  Component   = "web"
  Environment = "dev"
}

# Auto Scaling - Minimal
min_size             = 1    # Single instance
max_size             = 2    # Limited burst
desired_capacity     = 1
autoscaling_cpu_target = 80.0  # Tolerate high CPU

# Instance - Small
instance_type = "t2.micro"  # Free tier eligible
image_id      = "ami-dev-latest"

# Health Check - Relaxed
health_check = {
  path     = "/health"
  interval = 60  # Less frequent
  timeout  = 10
  healthy_threshold = 3
  unhealthy_threshold = 5
}

# Development domain
host_header   = "dev.example.com"
rule_priority = 100
```

**Benefits:**
- Minimal cost (free tier eligible)
- Adequate for testing
- Can burst during testing

---

## Module Usage Example

### Basic Usage

```hcl
module "web_asg" {
  source = "./terraform-asg-module"

  # Required variables
  project_name  = "myapp"
  env           = "production"
  common_tags = {
    Component   = "web"
    Environment = "production"
    ManagedBy   = "Terraform"
  }

  # Networking
  vpc_id                = module.vpc.vpc_id
  vpc_zone_identifier   = module.vpc.private_subnet_ids
  security_group_id     = aws_security_group.web.id

  # Instance configuration
  image_id      = data.aws_ami.latest_app.id
  instance_type = "t3.medium"
  key_name      = "myapp-keypair"
  user_data     = filebase64("${path.module}/scripts/user-data.sh")

  # Auto Scaling
  min_size             = 2
  max_size             = 8
  desired_capacity     = 2
  autoscaling_cpu_target = 70.0

  # Load Balancer
  alb_listener_arn = aws_lb_listener.main.arn
  rule_priority    = 10
  host_header      = "www.example.com"

  # Health Check
  health_check = {
    enabled             = true
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
    port                = 8080
    protocol            = "HTTP"
  }
}
```

### Advanced Usage with Multiple Components

```hcl
# Web tier
module "web_asg" {
  source = "./terraform-asg-module"

  project_name = "myapp"
  common_tags  = { Component = "web" }
  
  vpc_id                = module.vpc.vpc_id
  vpc_zone_identifier   = module.vpc.private_subnet_ids
  security_group_id     = aws_security_group.web.id
  
  image_id      = data.aws_ami.web.id
  instance_type = "t3.medium"
  key_name      = var.key_name
  
  min_size         = 2
  max_size         = 10
  desired_capacity = 2
  
  alb_listener_arn = aws_lb_listener.main.arn
  rule_priority    = 10
  host_header      = "www.example.com"
}

# API tier
module "api_asg" {
  source = "./terraform-asg-module"

  project_name = "myapp"
  common_tags  = { Component = "api" }
  
  vpc_id                = module.vpc.vpc_id
  vpc_zone_identifier   = module.vpc.private_subnet_ids
  security_group_id     = aws_security_group.api.id
  
  image_id      = data.aws_ami.api.id
  instance_type = "c5.large"
  key_name      = var.key_name
  
  min_size         = 3
  max_size         = 15
  desired_capacity = 3
  
  alb_listener_arn = aws_lb_listener.main.arn
  rule_priority    = 5
  host_header      = "api.example.com"
}

# Admin tier
module "admin_asg" {
  source = "./terraform-asg-module"

  project_name = "myapp"
  common_tags  = { Component = "admin" }
  
  vpc_id                = module.vpc.vpc_id
  vpc_zone_identifier   = module.vpc.private_subnet_ids
  security_group_id     = aws_security_group.admin.id
  
  image_id      = data.aws_ami.admin.id
  instance_type = "t3.small"
  key_name      = var.key_name
  
  min_size         = 1
  max_size         = 3
  desired_capacity = 1
  
  alb_listener_arn = aws_lb_listener.main.arn
  rule_priority    = 20
  host_header      = "admin.example.com"
}
```

---

## Troubleshooting Guide

### Issue 1: Instances Failing Health Checks

**Symptoms:**
- Instances marked as unhealthy
- Continuous instance termination and launch
- Traffic not reaching instances

**Common Causes & Solutions:**

1. **Application not listening on correct port**
   - Check: `netstat -tlnp | grep 8080`
   - Fix: Update application configuration

2. **Security group blocking health checks**
   - Check: Security group allows ALB traffic
   - Fix: Add ingress rule from ALB security group

3. **Health check path returns error**
   - Check: `curl localhost:8080/health`
   - Fix: Implement proper health endpoint

4. **Application takes too long to start**
   - Symptom: Instances terminated during startup
   - Fix: Increase `health_check_grace_period`

5. **Health check configuration mismatch**
   - Check: Path, port, protocol match application
   - Fix: Update `health_check` configuration

### Issue 2: Auto Scaling Not Working

**Symptoms:**
- CPU high but no new instances
- Instances not scaling in when load decreases

**Common Causes & Solutions:**

1. **Reached max_size limit**
   - Check: Current count vs max_size
   - Fix: Increase max_size if appropriate

2. **Cooldown period active**
   - Check: Recent scaling activity
   - Wait: 300s default cooldown

3. **Insufficient capacity**
   - Error: "InsufficientInstanceCapacity"
   - Fix: Try different instance type or AZ

4. **IAM permissions missing**
   - Error: Permission denied in CloudWatch
   - Fix: Add CloudWatch permissions to ASG role

5. **Policy disabled**
   - Check: Policy enabled status
   - Fix: Enable policy

### Issue 3: High Latency

**Symptoms:**
- Slow response times
- Timeouts

**Common Causes & Solutions:**

1. **Insufficient instances**
   - Check: CPU utilization across instances
   - Fix: Increase min_size or lower target CPU

2. **Instance in wrong subnet/AZ**
   - Check: Network path to instances
   - Fix: Ensure instances in private subnets with NAT

3. **Connection draining delay**
   - Check: Deregistration delay setting
   - Fix: Reduce if appropriate (default 300s)

4. **Application bottleneck**
   - Check: Application logs and metrics
   - Fix: Optimize application code or database

### Issue 4: Continuous Scaling (Flapping)

**Symptoms:**
- Instances constantly launching and terminating
- Unstable instance count

**Common Causes & Solutions:**

1. **Target value too low**
   - Symptom: Scales out too aggressively
   - Fix: Increase target_value (e.g., 70.0)

2. **Insufficient warmup time**
   - Symptom: New instances added before existing stabilize
   - Fix: Increase health_check_grace_period

3. **Application memory leak**
   - Symptom: CPU increases over time
   - Fix: Fix application code

---

## Security Considerations

### 1. Network Security

**Private Subnets:**
```hcl
# Launch instances in private subnets
vpc_zone_identifier = [
  "subnet-private-a",
  "subnet-private-b",
  "subnet-private-c"
]
```

**Security Group Configuration:**
```hcl
# Application security group
resource "aws_security_group" "app" {
  vpc_id = var.vpc_id

  # Only allow traffic from ALB
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow SSH from bastion only
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### 2. IAM Roles

**Instance Role:**
```hcl
resource "aws_iam_role" "instance" {
  name = "${var.project_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach necessary policies
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

### 3. Encryption

**EBS Encryption:**
```hcl
# In launch template
resource "aws_launch_template" "main" {
  # ... other config
  
  block_device_mappings {
    device_name = "/dev/sda1"
    
    ebs {
      encrypted   = true
      kms_key_id  = aws_kms_key.ebs.arn
      volume_size = 20
      volume_type = "gp3"
    }
  }
}
```

**HTTPS/TLS:**
Terminate TLS at ALB level for easier certificate management.

### 4. Secrets Management

**Never hardcode secrets in user_data!**

Use AWS Systems Manager Parameter Store or Secrets Manager:

```bash
#!/bin/bash
# In user_data script
DB_PASSWORD=$(aws ssm get-parameter \
  --name "/myapp/production/db_password" \
  --with-decryption \
  --query Parameter.Value \
  --output text)

# Use $DB_PASSWORD in application config
```

---

## Performance Optimization

### 1. Instance Right-Sizing

**Monitor these metrics:**
- CPU Utilization
- Memory Utilization
- Network Throughput
- Disk I/O

**Guidelines:**
- If CPU consistently <30%: Downsize instance
- If CPU frequently >80%: Upsize or scale out
- High memory usage: Use memory-optimized (r5/r6)
- High CPU usage: Use compute-optimized (c5/c6)

### 2. AMI Optimization

**Create Golden AMI:**
1. Pre-install application dependencies
2. Pre-configure application settings
3. Optimize OS settings
4. Remove unnecessary packages

**Benefits:**
- Faster boot time
- Shorter health_check_grace_period
- Faster scaling response

### 3. Connection Draining

**Optimize deregistration delay:**
```hcl
resource "aws_lb_target_group" "main" {
  # ... other config
  
  deregistration_delay = 30  # Reduce from default 300s
  # Only if your app has short request duration
}
```

### 4. Cross-Zone Load Balancing

Enabled by default for ALB, ensures even distribution across AZs.

---

## Cost Optimization Strategies

### 1. Instance Savings

**Reserved Instances:**
- 1-year: ~40% savings
- 3-year: ~60% savings
- Use for baseline min_size capacity

**Savings Plans:**
- More flexible than Reserved Instances
- Commit to consistent usage ($/hour)

**Spot Instances:**
```hcl
# Mixed instances policy (advanced)
mixed_instances_policy {
  instances_distribution {
    on_demand_base_capacity                  = 1
    on_demand_percentage_above_base_capacity = 25
    spot_allocation_strategy                 = "capacity-optimized"
  }
  
  launch_template {
    launch_template_specification {
      launch_template_id = aws_launch_template.main.id
    }
    
    override {
      instance_type = "t3.medium"
    }
    override {
      instance_type = "t3a.medium"
    }
  }
}
```

### 2. Right-Sizing

Monitor actual usage and adjust:
- Instance types
- Min/max capacity
- Target metrics

### 3. Scheduled Scaling

Scale down during predictable low-traffic periods.

### 4. Lifecycle Hooks

Execute custom actions during scale-in:
- Graceful shutdown
- Backup data
- Deregister from service discovery

---

## Summary

This module creates a **production-ready, auto-scaling infrastructure** with:

✅ **High Availability** - Multi-AZ deployment  
✅ **Auto Scaling** - CPU-based scaling with target tracking  
✅ **Health Monitoring** - Continuous health checks  
✅ **Load Balancing** - Intelligent traffic routing  
✅ **Security** - Private subnets, security groups  
✅ **Cost Optimization** - Scale in during low demand  

**Key Concepts Mastered:**
- Application Load Balancer architecture
- Target Groups and health checking
- Launch Templates for instance configuration
- Auto Scaling Groups for elasticity
- Scaling policies for automation
- Listener rules for traffic routing

**Production Checklist:**
- [ ] Multi-AZ subnets configured
- [ ] Security groups restrict access
- [ ] Health check endpoint implemented
- [ ] CloudWatch alarms configured
- [ ] Backup/disaster recovery plan
- [ ] Monitoring dashboard created
- [ ] Cost alerts configured
- [ ] Documentation updated

Use this guide as your complete reference for understanding and implementing AWS auto-scaling infrastructure with Terraform!
