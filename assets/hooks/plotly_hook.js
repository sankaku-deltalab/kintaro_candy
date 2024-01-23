import Plotly from "plotly.js-dist-min";

const chartLayout = {
  paper_bgcolor: "rgb(10,10,10)", // 背景色
  plot_bgcolor: "rgb(20,20,20)", // プロットエリアの背景色
  font: {
    color: "rgb(255,255,255)", // 文字色
  },
  xaxis: {
    gridcolor: "rgb(80,80,80)", // X軸のグリッドライン色
    linecolor: "rgb(80,80,80)", // X軸の線色
  },
  yaxis: {
    gridcolor: "rgb(80,80,80)", // Y軸のグリッドライン色
    linecolor: "rgb(80,80,80)", // Y軸の線色
  },
};

export const PlotlyHook = {
  mounted() {
    console.time("PlotlyHook mounted");
    const chartData = JSON.parse(this.el.dataset.chart_data);

    Plotly.newPlot(this.el, chartData, chartLayout);
    console.timeEnd("PlotlyHook mounted");
  },
  updated() {
    console.time("PlotlyHook updated");
    const chartData = JSON.parse(this.el.dataset.chart_data);

    Plotly.newPlot(this.el, chartData, chartLayout);
    console.timeEnd("PlotlyHook updated");
  },
};
