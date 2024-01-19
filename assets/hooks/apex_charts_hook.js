import ApexCharts from "apexcharts";

export const ApexChartsHook = {
  mounted() {
    const chart = new ApexCharts(this.el, JSON.parse(this.el.dataset.chart));
    chart.render();
    this.chart = chart;
  },
  updated() {
    this.chart.updateOptions(JSON.parse(this.el.dataset.chart));
  },
};
