data "aws_availability_zones" "available" {}

resource "aws_vpc" "mod" {
  cidr_block           = "${var.cidr}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"
  enable_dns_support   = "${var.enable_dns_support}"
  tags                 = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

resource "aws_internet_gateway" "mod" {
  vpc_id = "${aws_vpc.mod.id}"
  tags   = "${merge(var.tags, map("Name", format("%s-igw", var.name)))}"
}

resource "aws_route_table" "public" {
  vpc_id           = "${aws_vpc.mod.id}"
  propagating_vgws = ["${var.public_propagating_vgws}"]
  tags             = "${merge(var.tags, map("Name", format("%s-rt-public", var.name)))}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.mod.id}"
  }
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.natgw.*.id, count.index)}"
  count                  = "${length(data.aws_availability_zones.available.names) * var.enable_nat_gateway}"
}

resource "aws_route_table" "private" {
  vpc_id           = "${aws_vpc.mod.id}"
  propagating_vgws = ["${var.private_propagating_vgws}"]
  count            = "${length(data.aws_availability_zones.available.names)}"
  tags             = "${merge(var.tags, map("Name", format("%s-rt-private-%s", var.name, element(data.aws_availability_zones.available.names, count.index))))}"
}

resource "aws_subnet" "public" {
  vpc_id            = "${aws_vpc.mod.id}"
  cidr_block        = "${cidrsubnet(var.cidr, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count             = "${length(data.aws_availability_zones.available.names)}"
  tags              = "${merge(var.tags, map("Name", format("%s-public-%s", var.name, element(data.aws_availability_zones.available.names, count.index))))}"

  map_public_ip_on_launch = "${lookup(var.public_subnet, "map_public_ip_on_launch", false)}"
}

resource "null_resource" "private_subnets_info" {
  triggers = {
    subnet_name = "${element(var.private_subnets, count.index / length(data.aws_availability_zones.available.names))}"
    az_name     = "${element(data.aws_availability_zones.available.names, count.index % length(data.aws_availability_zones.available.names))}"
  }

  count = "${length(data.aws_availability_zones.available.names) * length(var.private_subnets)}"
}

resource "aws_subnet" "private" {
  vpc_id            = "${aws_vpc.mod.id}"
  cidr_block        = "${cidrsubnet(var.cidr, 8, count.index + length(aws_subnet.public.*.id))}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]}"
  count             = "${length(data.aws_availability_zones.available.names) * length(var.private_subnets)}"
  tags              = "${merge(var.tags, map("Name", format("%s-%s-%s", var.name, null_resource.private_subnets_info.*.triggers.subnet_name[count.index], null_resource.private_subnets_info.*.triggers.az_name[count.index])))}"
}

resource "aws_eip" "nateip" {
  vpc   = true
  count = "${length(data.aws_availability_zones.available.names) * var.enable_nat_gateway}"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = "${element(aws_eip.nateip.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  count         = "${length(data.aws_availability_zones.available.names) * var.enable_nat_gateway}"

  depends_on = ["aws_internet_gateway.mod"]
}

resource "aws_route_table_association" "private" {
  count          = "${length(data.aws_availability_zones.available.names) * length(var.private_subnets)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "public" {
  count          = "${length(data.aws_availability_zones.available.names)}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_vpc_endpoint" "private_s3" {
  vpc_id       = "${aws_vpc.mod.id}"
  service_name = "com.amazonaws.${var.region}.s3"
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  vpc_endpoint_id = "${aws_vpc_endpoint.private_s3.id}"
  route_table_id  = "${element(aws_route_table.private.*.id, count.index)}"
  count           = "${length(data.aws_availability_zones.available.names)}"
}
