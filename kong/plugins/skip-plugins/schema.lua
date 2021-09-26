-- schema.lua

return {
  name = "skip-plugins",
  fields = {
    {
      config = {
        type = "record",
        fields = {
          { plugin_names = { type = "string", encrypted = true, required = true}}
        },
      },
    },
  },
}

