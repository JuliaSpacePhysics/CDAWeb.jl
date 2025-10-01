# Benchmarking CDF format and NetCDF format reading performance
file = "/Users/zijin/.cdaweb/data/PSP_SWP_SPI_SF00_L3_MOM/psp_swps_spi_sf00_l3_mom_20210114002002_20210114005956_cdaweb.nc"
nc = NCDataset(file, "r"; maskingvalue = NaN)
@b NCDataset(file, "r"; maskingvalue = NaN)
sum(nc["DENS"][:])
@b sum(nc["DENS"][:])