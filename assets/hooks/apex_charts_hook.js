import ApexCharts from "apexcharts";

// NOTE: ApexCharts has nice visual but it's not good for performance.
export const ApexChartsHook = {
  mounted() {
    console.time("ApexChartsHook mounted");
    const chartTemplate = JSON.parse(this.el.dataset.chart_template);
    const chartSeries = JSON.parse(this.el.dataset.chart_series);
    const chartOption = { ...chartTemplate, series: chartSeries };

    const chart = new ApexCharts(this.el, chartOption);
    chart.render();
    this.chart = chart;
    this.chartSeriesJson = this.el.dataset.chart_series;
    console.timeEnd("ApexChartsHook mounted");
  },
  updated() {
    console.time("ApexChartsHook updated");

    // console.log("this.el.dataset.chart_series", this.el.dataset.chart_series);
    if (this.el.dataset.chart_series === this.chartSeriesJson) {
      console.timeEnd("ApexChartsHook updated");
      return;
    }

    const chartTemplate = JSON.parse(this.el.dataset.chart_template);
    let chartSeries = JSON.parse(this.el.dataset.chart_series);
    const chartOption = { ...chartTemplate, series: chartSeries };

    this.chart.updateOptions(chartOption);
    this.chartSeriesJson = this.el.dataset.chart_series;

    console.timeEnd("ApexChartsHook updated");
  },
};
