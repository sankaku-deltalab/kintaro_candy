import ApexCharts from "apexcharts";

export const ApexChartsHook = {
  mounted() {
    const chartTemplate = JSON.parse(this.el.dataset.chart_template);
    const chartSeries = JSON.parse(this.el.dataset.chart_series);
    const chartOption = { ...chartTemplate, series: chartSeries };

    const chart = new ApexCharts(this.el, chartOption);
    chart.render();
    this.chart = chart;
  },
  updated() {
    const chartTemplate = JSON.parse(this.el.dataset.chart_template);
    const chartSeries = JSON.parse(this.el.dataset.chart_series);
    const chartOption = { ...chartTemplate, series: chartSeries };

    this.chart.updateOptions(chartOption);
  },
};
