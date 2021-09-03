import React, { useRef, useEffect } from 'react';
import {
  LineTemporalChart,
  useMetricsTimeSpan,
} from '@scality/core-ui/dist/next';
import { useQuery, UseQueryOptions } from 'react-query';
import { GraphWrapper } from './DashboardMetrics';
import { formatNodesThroughputPromRangeForChart } from '../services/graphUtils';
import {
  queryThroughputReadAllInstances,
  queryThroughputWriteAllInstances,
} from '../services/prometheus/fetchMetrics';
import { useNodeAddressesSelector, useNodes } from '../hooks';
import { useStartingTimeStamp } from '../containers/StartTimeProvider';
import { YAXIS_TITLE_WRITE_READ } from '../constants';

const DashboardChartThroughput = (props: UseQueryOptions) => {
  const nodeAddresses = useNodeAddressesSelector(useNodes());
  const { startingTimeISO, currentTimeISO } = useStartingTimeStamp();
  const { sampleFrequency } = useMetricsTimeSpan();
  const startTimeRef = useRef(startingTimeISO);
  const chartStartTimeRef = useRef(startingTimeISO); //IMPORTANT: the ref of the previous start time
  const seriesRef = useRef();
  // Passing nodes table as a react-queries identifier so if a node is added/removed the data are refreshed
  // Also it makes the data to auto-refresh based on the node refresh timeout that is already implemented
  const throughputQuery = useQuery({
    queryKey: ['throughputQuery', nodeAddresses, startingTimeISO],
    queryFn: () => {
      startTimeRef.current = startingTimeISO;
      return Promise.all([
        queryThroughputReadAllInstances(
          sampleFrequency,
          startingTimeISO,
          currentTimeISO,
        ),
        queryThroughputWriteAllInstances(
          sampleFrequency,
          startingTimeISO,
          currentTimeISO,
        ),
      ]).then((result) => {
        return formatNodesThroughputPromRangeForChart(result, nodeAddresses);
      });
    },
    ...props.reactQueryOptions,
  });

  const isDataLoading = throughputQuery.status === 'loading';

  useEffect(() => {
    if (!isDataLoading) {
      chartStartTimeRef.current = startTimeRef.current;
      seriesRef.current = throughputQuery.data;
    }
  }, [isDataLoading, nodeAddresses, throughputQuery.data]);

  return (
    <GraphWrapper>
      <LineTemporalChart
        series={seriesRef.current || []}
        title='Disk Throughput'
        height={150}
        yAxisType={'symmetrical'}
        unitRange={[
          { threshold: 0, label: 'B/s' },
          { threshold: 1024, label: 'KiB/s' },
          { threshold: 1024 * 1024, label: 'MiB/s' },
          { threshold: 1024 * 1024 * 1024, label: 'GiB/s' },
          { threshold: 1024 * 1024 * 1024 * 1024, label: 'TiB/s' },
        ]}
        startingTimeStamp={Date.parse(chartStartTimeRef.current) / 1000}
        isLegendHided={false}
        yAxisTitle={YAXIS_TITLE_WRITE_READ}
        isLoading={isDataLoading}
      />
    </GraphWrapper>
  );
};

export default DashboardChartThroughput;
