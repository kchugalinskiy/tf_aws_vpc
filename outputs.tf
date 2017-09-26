output "subnets" {
  value = {}
}

resource "null_resource" "private_subnets_creation_results" {
  triggers = {
    name       = "${aws_subnet.private.*.tags.Name}"
    id         = "${aws_subnet.private.*.id}"
    cidr_block = "${aws_subnet.private.*.cidr_block}"
  }

  count = "${length(data.aws_availability_zones.available.names) * length(var.private_subnets)}"
}

resource "null_resource" "private_subnets" {
  triggers = {
    name    = "${var.private_subnets[count.index]}"
    subnets = "${slice(null_resource.private_subnets_creation_results.*.triggers, count.index * length(data.aws_availability_zones.available.names), (count.index + 1) * length(data.aws_availability_zones.available.names))}"
  }

  count = "${length(var.private_subnets)}"
}

output "private_subnets" {
  value = ["${null_resource.private_subnets.*.triggers}"]
}

output "public_subnets" {
  value = ["${aws_subnet.public.*.id}"]
}

output "vpc_id" {
  value = "${aws_vpc.mod.id}"
}

output "public_route_table_ids" {
  value = ["${aws_route_table.public.*.id}"]
}

output "private_route_table_ids" {
  value = ["${aws_route_table.private.*.id}"]
}

output "default_security_group_id" {
  value = "${aws_vpc.mod.default_security_group_id}"
}

output "nat_eips" {
  value = ["${aws_eip.nateip.*.id}"]
}

output "nat_eips_public_ips" {
  value = ["${aws_eip.nateip.*.public_ip}"]
}

output "natgw_ids" {
  value = ["${aws_nat_gateway.natgw.*.id}"]
}

output "igw_id" {
  value = "${aws_internet_gateway.mod.id}"
}
