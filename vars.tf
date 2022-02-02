variable AWS_ACCESS_KEY {}
variable AWS_SECRET_KEY {}
variable AWS_REGION {
    default = "us-west-2"
}
variable INTEGRATION_HOST {}

variable MAPPING {
    type = list(object({key=string, model=string, vtl=string}))
    default = [
        {
            "key": "route",
            "model": "mappings/models/sample.json",
            "vtl": "mappings/vtls/sample.vtl"
        }
    ]
}
