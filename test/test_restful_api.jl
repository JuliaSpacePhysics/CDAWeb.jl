using Dates

@testset "RESTful Web Services" begin
    res = CDAWeb.get_dataviews()
    @test length(res) > 0
    @test res[1].Id == "sp_phys"

    datasets = get_datasets(; observatoryGroup = "ACE", instrument = "MAG")
    @test length(datasets) > 0

    itypes = CDAWeb.get_instrument_types()
    @test length(itypes) > 0

    instruments = CDAWeb.get_instruments(; instrumentType = itypes[end].Name)
    @test length(instruments) > 0

    observatories = CDAWeb.get_observatories(; instrument = instruments[end].Name)
    @test length(observatories) == 1

    ogs = CDAWeb.get_observatory_groups(; instrumentType = itypes[end].Name)
    @test length(ogs) > 0

    ogis = CDAWeb.get_observatory_groups_and_instruments(; instrumentType = itypes[end].Name)
    @test length(ogis) > 0

    res = get_inventory("OMNI_COHO1HR_MERGED_MAG_PLASMA", DateTime(2020, 1, 1), DateTime(2020, 1, 2))
    @test first(only(res)) <= DateTime(2020, 1, 1) < last(only(res))

    get_original_file_descs("OMNI_COHO1HR_MERGED_MAG_PLASMA", DateTime(2020, 1, 1), DateTime(2020, 2, 1))

    get_data_file_descs("OMNI_COHO1HR_MERGED_MAG_PLASMA", ["BR", "BT", "BN"], DateTime(2020, 1, 1), DateTime(2020, 1, 2))
    get_data_file_descs("OMNI_COHO1HR_MERGED_MAG_PLASMA", ["BR", "BT", "BN"], DateTime(2020, 1, 1), DateTime(2020, 1, 2); format = "png")
end
