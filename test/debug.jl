using CDAWeb
using CDFDatasets
using Dates
using Test

CDAWeb.get_data_files("OMNI_HRO_1MIN", "Beta", DateTime(2020, 2, 1), DateTime(2020, 2, 11); orig=true)
CDAWeb.get_data_files("OMNI_HRO_1MIN", "Beta", DateTime(2020, 2, 1), DateTime(2020, 3, 11); orig=true)
@test CDAWeb.cache_metadata(true)