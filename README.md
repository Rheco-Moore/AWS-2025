Implementing three isolated environments (Test, Development, Production) following GitFlow methodology for secure, controlled deployments.
Resource Specifications
Resource	Test	Development	Production
Instance Type	t3.micro	t3.small	m5.large
Multi-AZ	No	Limited	Full
NAT Gateway	Single	Single	Multi-AZ
Monitoring	Basic	Enhanced	Comprehensive
SSH Access	0.0.0.0/0	0.0.0.0/0	VPC-only
Cost Profile	$	$$	$$$
Security Overview
Environment-specific Security Policies
Test: Open access for rapid testing
Development: Balanced access for development
Production: Strict least-privilege access
