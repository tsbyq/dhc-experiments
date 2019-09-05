console.log('JS loaded...');

var LOADSHAPE_SOURCE_OPTIONS = ["User Upload", "From Simulation"];
var DS_TYPES = ["Central Water-cooled Chiller + Boiler", "Central Air-cooled Chiller + Boiler", "Ground Source Heat Pump"];

var self = this;

self.heating_cooling_demand_ts_chart_id = 'ts_viz_container_1';
self.energy_consumption_ts_chart_id = 'ts_viz_container_2';
self.dummy_chart_1_id = 'dummy_bar_viz_container';
self.dummy_chart_2_id = 'dummy_pie_viz_container_1';
self.dummy_chart_3_id = 'dummy_pie_viz_container_2';


function uploadLoadsProfile() {

    console.log('In the file uploader function now...');

    if (!window.FileReader) return;
    var fileUpload = document.getElementById("load_profile_csv");
    var loadProfileFile = fileUpload.files[0];

    if (loadProfileFile != null && loadProfileFile.name != null) {
        console.log(loadProfileFile.name);
        var reader = new FileReader();
        reader.readAsText(loadProfileFile);
        reader.onload = function (event) {
            var csvText = event.target.result;
            var parseConfig = {
                header: true,
                dynamicTyping: true,
                skipEmptyLines: true,
            };
            var data = Papa.parse(csvText, parseConfig);
            prepareLoadProfile(data);
            createHCDemandTSHighchart();
            createEnergyConsumptionTSHighchart();
            calculateKeyStats();
            prepareOtherChartData(); // TODO: bind real data (This is temporary.)
            createOtherDummyChart();
            // self.createDemandBinChart();
        };
    }
}

prepareLoadProfile = function (rawData) {
    // For time-series loadprofile charts
    var heatingTSData = [];
    var coolingTSData = [];
    var netLoadTSData = [];
    var electricityTSData = [];
    var naturalGasTSData = [];
    var simultaneousLoadTSData = [];

    // For key stats data table
    var v_timestamps = [];
    var v_heating_demand = [];
    var v_cooling_demand = [];
    var v_simultaneous_demand = [];
    var v_electricity_consumption = [];
    var v_gas_consumption = [];

    for (i = 0; i < rawData.data.length; i++) {
        var timeMillisecond = Date.parse(rawData.data[i].Datetime);
        var heatingDemand = Math.round(rawData.data[i]['Heating Demand (kWh)']);
        var coolingDemand = Math.round(rawData.data[i]['Cooling Demand (kWh)']);
        var simultaneousDemand = Math.min(heatingDemand, coolingDemand);
        var electricityConsumption = Math.round(rawData.data[i]['Electricity Consumption (kWh)']);
        var naturalGasConsumption = Math.round(rawData.data[i]['Natural Gas Consumption (Therms)']);

        v_timestamps.push(timeMillisecond);
        v_heating_demand.push(heatingDemand);
        v_cooling_demand.push(coolingDemand);
        v_simultaneous_demand.push(simultaneousDemand);
        v_electricity_consumption.push(electricityConsumption);
        v_gas_consumption.push(naturalGasConsumption);

        heatingTSData.push([timeMillisecond, heatingDemand]);
        coolingTSData.push([timeMillisecond, coolingDemand]);
        electricityTSData.push([timeMillisecond, electricityConsumption]);
        naturalGasTSData.push([timeMillisecond, naturalGasConsumption]);
        simultaneousLoadTSData.push([timeMillisecond, simultaneousDemand]);
    }

    self.v_timestamps = v_timestamps;
    self.v_heating_demand = v_heating_demand;
    self.v_cooling_demand = v_cooling_demand;
    self.v_simultaneous_demand = v_simultaneous_demand;
    self.v_electricity_consumption = v_electricity_consumption;
    self.v_gas_consumption = v_gas_consumption;

    self.heatingTSData = heatingTSData;
    self.coolingTSData = coolingTSData;
    self.electricityTSData = electricityTSData;
    self.naturalGasTSData = naturalGasTSData;
    self.simultaneousLoadTSData = simultaneousLoadTSData;

};

this.prepareOtherChartData = function () {
    self.somedata = 1;
};

const arrSum = arr => arr.reduce((a, b) => a + b, 0);

this.simpsonDiversity = function (arr, chunkSize = 200) {
        // This function chunk original array into groups and calculate the Simpson's diversity index based on the groups.
        var lower = Math.min.apply(null, arr);
        var upper = Math.max.apply(null, arr) + chunkSize;
        var temp_lower = lower;
        var temp_upper = lower + chunkSize;
        var v_counts = [];

        // console.log('Lower is ' + lower + ', Upper is ' + upper);

        arr = arr.sort(function (a, b) {
            return a - b
        });
        i = 0;
        do {
            // console.log('Temp lower = ' + temp_lower + ', Tempe upper = ' + temp_upper);
            // Count the number of elements in a group
            j = i;
            count = 0;
            do {
                if (arr[j] >= temp_lower && arr[j] < temp_upper) {
                    // console.log(arr[j]);
                    count += 1;
                    j += 1;
                } else {
                    break
                }
            }
            while (true);

            if (count > 0) {
                v_counts.push(count);
            }
            i = j;
            temp_lower = temp_upper;
            temp_upper += chunkSize;
        }
        while (temp_upper <= upper);

        // Calculate Simpson's diversity index
        numerator = 0;
        denominator = arr.length * (arr.length - 1);
        v_counts.forEach(function (count) {
            numerator += count * (count - 1)
        });

        // console.log(v_counts);
        return Math.round((1 - numerator / denominator) * 100 * 10) / 10;
    };

this.calculateKeyStats = function () {
    // This function calculate the key statistics for the district heating and cooling demand profiles.

    console.log('Calculating key statistics...');

    var peak_heating_demand = Math.max.apply(null, self.v_heating_demand);
    var peak_heating_demand_time = new Date(self.v_timestamps[self.v_heating_demand.indexOf(peak_heating_demand)]); // to date time string
    var annual_heating_demand_intensity = 0;
    var annual_heating_demand_diversity = self.simpsonDiversity(self.v_heating_demand);

    var peak_cooling_demand = Math.max.apply(null, self.v_cooling_demand);
    var peak_cooling_demand_time = new Date(self.v_timestamps[self.v_cooling_demand.indexOf(peak_cooling_demand)]);
    var annual_cooling_demand_intensity = 0;
    var annual_cooling_demand_diversity = self.simpsonDiversity(self.v_cooling_demand);

    var peak_heating_cooling_demand = Math.max.apply(null, self.v_simultaneous_demand);
    var peak_heating_cooling_demand_time = new Date(self.v_timestamps[self.v_simultaneous_demand.indexOf(peak_heating_cooling_demand)]);
    var annual_heating_cooling_demand_intensity = 0;
    var annual_heating_cooling_demand_diversity = self.simpsonDiversity(self.v_simultaneous_demand);

    var peak_electricity_consumption = Math.max.apply(null, self.v_electricity_consumption);
    var peak_electricity_consumption_time = new Date(self.v_timestamps[self.v_electricity_consumption.indexOf(peak_electricity_consumption)]);
    var annual_electricity_consumption_intensity = 0;
    var annual_electricity_consumption_diversity = self.simpsonDiversity(self.v_electricity_consumption);

    var peak_ng_consumption = Math.max.apply(null, self.v_gas_consumption);
    var peak_ng_consumption_time = new Date(self.v_timestamps[self.v_gas_consumption.indexOf(peak_ng_consumption)]);
    var annual_ng_consumption_intensity = 0;
    var annual_ng_consumption_diversity = self.simpsonDiversity(self.v_gas_consumption);
    var annual_heat_recovery_potential = Math.abs(arrSum(self.v_simultaneous_demand));

    document.getElementById("peak_heating_demand").innerHTML = peak_heating_demand.toLocaleString() + " kWh";
    document.getElementById("peak_heating_demand_time").innerHTML = peak_heating_demand_time.toLocaleString();
    document.getElementById("annual_heating_demand_intensity").innerHTML = annual_heating_demand_intensity.toLocaleString() + " kWh/(sqm*yr)";
    document.getElementById("annual_heating_demand_diversity").innerHTML = annual_heating_demand_diversity.toLocaleString() + " %";
    document.getElementById("peak_cooling_demand").innerHTML = peak_cooling_demand.toLocaleString() + " kWh";
    document.getElementById("peak_cooling_demand_time").innerHTML = peak_cooling_demand_time.toLocaleString();
    document.getElementById("annual_cooling_demand_intensity").innerHTML = annual_cooling_demand_intensity.toLocaleString() + " kWh/(sqm*yr)";
    document.getElementById("annual_cooling_demand_diversity").innerHTML = annual_cooling_demand_diversity.toLocaleString() + " %";
    document.getElementById("peak_heating_cooling_demand").innerHTML = peak_heating_cooling_demand.toLocaleString() + " kWh";
    document.getElementById("peak_heating_cooling_demand_time").innerHTML = peak_heating_cooling_demand_time.toLocaleString();
    document.getElementById("annual_heating_cooling_demand_intensity").innerHTML = annual_heating_cooling_demand_intensity.toLocaleString() + " kWh/(sqm*yr)";
    document.getElementById("annual_heating_cooling_demand_diversity").innerHTML = annual_heating_cooling_demand_diversity.toLocaleString() + " %";
    document.getElementById("peak_electricity_consumption").innerHTML = peak_electricity_consumption.toLocaleString() + " kWh";
    document.getElementById("peak_electricity_consumption_time").innerHTML = peak_electricity_consumption_time.toLocaleString();
    document.getElementById("annual_electricity_consumption_intensity").innerHTML = annual_electricity_consumption_intensity.toLocaleString() + " kWh/(sqm*yr)";
    document.getElementById("annual_electricity_consumption_diversity").innerHTML = annual_electricity_consumption_diversity.toLocaleString() + " %";
    document.getElementById("peak_ng_consumption").innerHTML = peak_ng_consumption.toLocaleString() + " Therms";
    document.getElementById("peak_ng_consumption_time").innerHTML = peak_ng_consumption_time.toLocaleString();
    document.getElementById("annual_ng_consumption_intensity").innerHTML = annual_ng_consumption_intensity.toLocaleString() + " Therms/(sqm*yr)";
    document.getElementById("annual_ng_consumption_diversity").innerHTML = annual_ng_consumption_diversity.toLocaleString() + " %";
    document.getElementById("annual_heat_recovery_potential").innerHTML = annual_heat_recovery_potential.toLocaleString() + " kWh";

    document.getElementById("key_stats_table").style.display = 'block';

    console.log('Key stats rendering done...');

};

this.createHCDemandTSHighchart = function () {
    self.myHeatingCoolingTSChart = Highcharts.chart({
        chart: {
            type: 'area',
            renderTo: self.heating_cooling_demand_ts_chart_id,
            zoomType: 'x',
        },
        title: {
            text: 'District heating and cooling demands'
        },
        subtitle: {
            text: document.ontouchstart === undefined ?
                'Click and drag in the plot area to zoom in' : 'Pinch the chart to zoom in'
        },
        xAxis: {
            type: 'datetime'
        },
        yAxis: {
            title: {
                text: 'Load (kWh)'
            }
        },
        credits: {
            enabled: false
        },
        legend: {
            enabled: true
        },
        tooltip: {
            enabled: true,
            shared: true
        },
        series: [{
            type: 'area',
            name: 'Heating Demand (kWh)',
            color: '#e34839',
            fillOpacity: 0.5,
            lineWidth: 0.5,
            data: self.heatingTSData
        }, {
            type: 'area',
            name: 'Cooling Demand (kWh)',
            color: '#0090FF',
            fillOpacity: 0.5,
            lineWidth: 0.5,
            data: self.coolingTSData
        }, {
            type: 'area',
            name: 'Simultaneous Demand (kWh)',
            color: '#3c1e46',
            fillOpacity: 0.5,
            lineWidth: 0.5,
            data: self.simultaneousLoadTSData
        }]
    });
};

this.createEnergyConsumptionTSHighchart = function () {
    self.myHeatingCoolingTSChart = Highcharts.chart({
        chart: {
            type: 'area',
            renderTo: self.energy_consumption_ts_chart_id,
            zoomType: 'x',
        },
        title: {
            text: 'District electricity and natural gas consumption'
        },
        subtitle: {
            text: document.ontouchstart === undefined ?
                'Click and drag in the plot area to zoom in' : 'Pinch the chart to zoom in'
        },
        xAxis: {
            type: 'datetime'
        },
        yAxis: [
            {
                title: {
                    text: 'kWh'
                }
            },
            {
                title: {
                    text: 'Terms'
                },
                opposite: true
            },
        ],
        credits: {
            enabled: false
        },
        legend: {
            enabled: true
        },
        tooltip: {
            enabled: true,
            shared: true
        },
        series: [{
            type: 'area',
            name: 'Electricity Consumption (kWh)',
            yAxis: 0,
            color: '#2bd3e3',
            fillOpacity: 0.5,
            lineWidth: 0.5,
            data: self.electricityTSData
        }, {
            type: 'area',
            name: 'Natural Gas Consumption (Therms)',
            yAxis: 1,
            color: '#ffe049',
            fillOpacity: 0.5,
            lineWidth: 0.5,
            data: self.naturalGasTSData
        }]
    });
};

this.createOtherDummyChart = function () {
    console.log('Creating dummy charts...');
    self.dummy_chart_1 = Highcharts.chart({
        chart: {
            type: 'column',
            renderTo: self.dummy_chart_1_id
        },
        title: {
            text: 'District Monthly Heating and Cooling Energy Consumption by Building Types'
        },
        xAxis: {
            categories: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        },
        yAxis: {
            allowDecimals: false,
            min: 0,
            title: {
                text: 'kWh'
            }
        },
        tooltip: {
            formatter: function () {
                return '<b>' + this.x + '</b><br/>' +
                    this.series.name + ': ' + this.y + '<br/>' +
                    'Total: ' + this.point.stackTotal;
            }
        },
        plotOptions: {
            column: {
                stacking: 'normal'
            }
        },
        series: [{
            name: 'Office - Cooling',
            data: [292153.6111, 308868.3442, 737089.0172, 1085612.627, 1770409.734, 2079552.403, 2300245.292, 2241646.409, 1956413.242, 1356283.937, 846760.1342, 277975.6851],
            stack: 'Cooling'
        }, {
            name: 'Hospital - Cooling',
            data: [221938.2674, 260110.2377, 363542.1088, 402512.9937, 418164.0964, 380355.5334, 374949.2798, 382376.8086, 390099.8663, 421273.878, 383623.0412, 307174.672],
            stack: 'Cooling'
        }, {
            name: 'Retail - Cooling',
            data: [0, 8.21902137, 3377.189543, 11774.94596, 73846.23703, 163755.6767, 282844.215, 222109.9156, 98876.70262, 6136.555457, 892.242284, 0],
            stack: 'Cooling'
        }, {
            name: 'Residential - Cooling',
            data: [0, 0, 0, 287.3317832, 6289.101408, 20718.10032, 53436.21676, 38653.35613, 17234.14194, 777.1162586, 0, 0],
            stack: 'Cooling'
        }, {
            name: 'Office - Heating',
            data: [3822957.663, 1996092.904, 1073511.533, 460831.3951, 158317.6365, 5361.453705, 658.4842011, 8869.029521, 49607.23203, 380461.8028, 855611.2426, 2442369.258],
            stack: 'Heating'
        }, {
            name: 'Hospital - Heating',
            data: [462304.9014, 368309.5828, 354946.4285, 313376.3613, 281121.0704, 240764.6739, 177024.9751, 207312.9504, 252386.5369, 321409.8875, 342025.1861, 415866.3255],
            stack: 'Heating'
        }, {
            name: 'Retail - Heating',
            data: [1720217.728, 1227569.812, 804350.8291, 371795.2935, 91040.88892, 845.9903772, 0, 0, 5222.289571, 232777.4336, 592271.1948, 1356438.321],
            stack: 'Heating'
        }, {
            name: 'Residential - Heating',
            data: [769316.7508, 563537.0094, 427271.0315, 242490.7338, 70526.89067, 0, 0, 0, 0, 73745.68386, 226128.2205, 563182.1851],
            stack: 'Heating'
        }]
    });

    self.dummy_chart_2 = Highcharts.chart({
        chart: {
            type: 'pie',
            renderTo: self.dummy_chart_2_id,
        },
        title: {
            text: 'District Annual Cooling Energy Consumption by Building Types'
        },
        tooltip: {
            pointFormat: '{series.name}: <b>{point.percentage:.1f}%</b>'
        },
        plotOptions: {
            pie: {
                allowPointSelect: true,
                cursor: 'pointer',
                depth: 35,
                dataLabels: {
                    enabled: true,
                    format: '{point.name}'
                }
            }
        },
        series: [{
            type: 'pie',
            name: 'Cooling Energy',
            data: [
                {
                    name: 'Office',
                    y: 15253010.44,
                    sliced: true,
                    selected: true
                },
                ['Retail', 863621.8992],
                ['Hospital', 4306120.783],
                ['Residential', 137395.3646]
            ]
        }]
    });

    self.dummy_chart_3 = Highcharts.chart({
        chart: {
            type: 'pie',
            renderTo: self.dummy_chart_3_id,
        },
        title: {
            text: 'District Annual Heating Energy Consumption by Building Types'
        },
        tooltip: {
            pointFormat: '{series.name}: <b>{point.percentage:.1f}%</b>'
        },
        plotOptions: {
            pie: {
                allowPointSelect: true,
                cursor: 'pointer',
                depth: 35,
                dataLabels: {
                    enabled: true,
                    format: '{point.name}'
                }
            }
        },
        series: [{
            type: 'pie',
            name: 'Cooling Energy',
            data: [
                {
                    name: 'Office',
                    y: 11254649.63,
                    sliced: true,
                    selected: true
                },
                ['Retail', 6402529.781],
                ['Hospital', 3736848.88],
                ['Residential', 2936198.506]
            ]
        }]
    });
};