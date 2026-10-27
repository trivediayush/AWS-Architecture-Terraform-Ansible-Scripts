# Limited Ansible scope

- `staging-baseline.yml`: updates packages, installs basic operational utilities and enables chrony on the single staging EC2. Connects using SSH and the existing EC2 key pair's private PEM file. It does not install an application runtime because the application deployment method is not confirmed.
- `database-bootstrap.yml`: creates separate staging and production PostgreSQL databases/users. Run only from an approved host with network access to private RDS and PostgreSQL Python dependencies installed. Credentials must be injected from the approved secret store as environment variables. Tasks use `no_log`.

Install collections: `ansible-galaxy collection install -r ansible/requirements.yml`.

## SSH / PEM access

1. Create or import an EC2 key pair in the approved AWS region before applying EC2 components. Set `key_pair_name` to that key pair's name in the staging and production ECS component variable files. AWS does not let you download the private key again after creating a key pair; store the PEM securely.
2. Set `admin_ssh_cidr` in the security-group variables to your trusted public IP as `/32`. Do not use `0.0.0.0/0`.
3. Restrict PEM file permissions: `chmod 400 /path/to/key.pem`.
4. Run Ansible with the PEM path: `ANSIBLE_PRIVATE_KEY_FILE=/path/to/key.pem ansible-playbook ansible/playbooks/staging-baseline.yml -i ansible/inventory/aws_ec2.yml`. If needed, pass `-e ansible_ssh_private_key_file=/path/to/key.pem`.
5. Staging inventory uses the public IP. SSH requires the instance to have a public IP and a route through an internet gateway. Production ECS instances are in private subnets; the PEM alone does not provide network reachability. Do not expose production SSH publicly. Use the client's existing approved VPN/private network path if one exists; no bastion is added in this scope.

Before running DB bootstrap, ensure the DB endpoint is reachable from the execution host, RDS certificate validation is supported by the installed PostgreSQL driver, and the admin/user credentials come from the approved secret store. Adjust database names only with DB-owner approval.
