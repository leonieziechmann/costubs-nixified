{
  description = "A template for the CoStuBs Nixified development environment";

  outputs = { self }: {

    templates.default = {
      path = ./template;
      description = "CoStuBs environment with Bochs, cross-compilers, and ISO tools";
    };

    templates.costubs = self.templates.default;
  };
}
