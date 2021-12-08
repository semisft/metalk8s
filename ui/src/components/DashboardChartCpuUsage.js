import React, { useCallback } from 'react';
import { useIntl } from 'react-intl';
import { LineTemporalChart } from '@scality/core-ui/dist/next';
import { getMultiResourceSeriesForChart } from '../services/graphUtils';
import {
  useNodeAddressesSelector,
  useNodes,
  useShowQuantileChart,
  useSingleChartSerie,
} from '../hooks';
import {
  getNodesCPUUsageOutpassingThresholdQuery,
  getNodesCPUUsageQuantileQuery,
  getNodesCPUUsageQuery,
} from '../services/platformlibrary/metrics';
import NonSymmetricalQuantileChart from './NonSymmetricalQuantileChart';

const DashboardChartCpuUsage = () => {
  const intl = useIntl();
  const { isShowQuantileChart } = useShowQuantileChart();

  return (
    <>
      {isShowQuantileChart ? (
        <NonSymmetricalQuantileChart
          getQuantileQuery={getNodesCPUUsageQuantileQuery}
          getQuantileHoverQuery={getNodesCPUUsageOutpassingThresholdQuery}
          title={'CPU Usage'}
          yAxisType={'percentage'}
          helpText={
            <span style={{ textAlign: 'left', display: 'block' }}>
              {intl.formatMessage({
                id: 'dashboard_cpu_quantile_explanation_line1',
              })}
              <br />
              <br />
              {intl.formatMessage({
                id: 'dashboard_cpu_quantile_explanation_line2',
              })}
              <br />
              <br />
              {intl.formatMessage({
                id: 'dashboard_cpu_quantile_explanation_line3',
              })}
              <br />
              <br />
              {intl.formatMessage({
                id: 'dashboard_cpu_quantile_explanation_line4',
              })}
              <br />
              <br />
              {intl.formatMessage({
                id: 'dashboard_cpu_quantile_explanation_line5',
              })}
            </span>
          }
        />
      ) : (
        <DashboardChartCpuUsageWithoutQuantils />
      )}
    </>
  );
};

const DashboardChartCpuUsageWithoutQuantils = () => {
  const nodeAddresses = useNodeAddressesSelector(useNodes());

  const { isLoading, series, startingTimeStamp } = useSingleChartSerie({
    getQuery: (timeSpanProps) => getNodesCPUUsageQuery(timeSpanProps),
    transformPrometheusDataToSeries: useCallback(
      (prometheusResult) =>
        getMultiResourceSeriesForChart(prometheusResult, nodeAddresses),
      // eslint-disable-next-line react-hooks/exhaustive-deps
      [JSON.stringify(nodeAddresses)],
    ),
  });

  return (
    <LineTemporalChart
      series={series}
      height={80}
      title="CPU Usage"
      startingTimeStamp={startingTimeStamp}
      yAxisType={'percentage'}
      isLegendHidden={true}
      isLoading={isLoading}
    />
  );
};

export default DashboardChartCpuUsage;
