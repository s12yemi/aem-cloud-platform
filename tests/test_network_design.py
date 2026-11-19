"""Dependency-free static invariants; not a substitute for terraform validate/plan."""
from pathlib import Path
import ipaddress

root = Path(__file__).resolve().parents[1]
module = (root / 'modules/networking/main.tf').read_text()
assert 'map_public_ip_on_launch = false' in module
assert 'resource "aws_internet_gateway" "this"' in module
assert 'resource "aws_vpc_endpoint" "s3"' in module
assert 'resource "aws_route_table" "database"' in module
assert 'resource "aws_route" "app_nat"' in module
assert 'var.nat_mode == "none" ? {}' in module
for env, prefix in [('dev', 20), ('staging', 30), ('prod', 40)]:
    stack = root / 'environments' / env
    variables = (stack / 'variables.tf').read_text()
    assert f'10.{prefix}.0.0/16' in variables
    cfg = (stack / 'backend.hcl.example').read_text()
    assert f'aem-cloud-platform/{env}/networking.tfstate' in cfg
    assert 'use_lockfile = true' in cfg
    assert 'encrypt      = true' in cfg
    assert 'nat_mode' in variables
    for n in (0, 1, 10, 11, 20, 21):
        subnet = ipaddress.ip_network(f'10.{prefix}.{n}.0/24')
        assert subnet.subnet_of(ipaddress.ip_network(f'10.{prefix}.0.0/16'))
print('PASS: subnet CIDRs, environment state keys, lockfiles, and core security intent')
