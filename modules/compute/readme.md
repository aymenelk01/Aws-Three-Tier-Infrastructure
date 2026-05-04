## Lessons Learned

### SSM Agent Not Pre-installed on AL2023 AMI in eu-south-1

**Issue:** EC2 instances were not appearing in AWS Systems Manager Fleet Manager 
despite correct IAM role, instance profile, and network configuration.

**Root Cause:** The Amazon Linux 2023 AMI (`ami-0fa01ed9c3147ad57`) in `eu-south-1` 
does not have SSM Agent pre-installed, contrary to AWS documentation which states 
AL2023 AMIs include SSM Agent by default.

**Debugging Process:**
- Verified IAM role and instance profile were correctly attached
- Verified NAT Gateway routing was correct
- Verified outbound port 443 was open
- Used nginx as a proxy to read instance logs via browser (creative workaround 
  for instances with no direct access)
- Discovered `amazon-ssm-agent.service could not be found` confirming agent 
  was missing entirely

**Solution:** Explicitly install SSM Agent in `user_data.sh`:
```bash
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
```

**Takeaway:** Never assume AMI pre-installation. Always explicitly install and 
start SSM Agent in user data for reliable Session Manager access, regardless 
of AMI documentation.