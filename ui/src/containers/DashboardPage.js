//@flow
import React from 'react';
import styled from 'styled-components';
import DashboardMetrics from '../components/DashboardMetrics';
import DashboardInventory from '../components/DashboardInventory';
import DashboardServices from '../components/DashboardServices';
import DashboardGlobalHealth from '../components/DashboardGlobalHealth';
import { padding, spacing } from '@scality/core-ui/dist/style/theme';
import { SyncedCursorCharts } from '@scality/core-ui/dist/components/vegachartv2/SyncedCursorCharts';
import TimespanSelector from './TimespanSelector';
import DashboardCPBandwidthChart from '../components/DashboardCPBandwidthChart';

const DashboardGrid = styled.div`
  display: grid;
  gap: 8px;
  grid-template:
    'header header header header header' 40px
    'health     health  health  health  health' 100px
    'inventory  network network metrics metrics' auto
    / 1fr 1fr 1fr 1fr 1fr;

  height: calc(100vh - 48px - 8px);
  margin: 0 8px 0 8px;

  > div {
    background-color: ${(props) => {
      return props.theme.backgroundLevel3;
    }};
    color: ${(props) => props.theme.textPrimary};
    padding: 2px ${spacing.sp4};
    .sc-vegachart svg {
      background-color: inherit !important;
    }
  }
  .health {
    grid-area: health;
    background-color: ${(props) => props.theme.backgroundLevel2};
  }
  .inventory {
    grid-area: inventory;
    padding: ${spacing.sp8} ${spacing.sp12};
  }
  .alerts {
    grid-area: alerts;
  }
  .services {
    grid-area: services;
  }
  .network {
    grid-area: network;
    display: flex;
  }
  .header {
    grid-area: header;
    display: flex;
    justify-content: flex-end;
    padding: ${padding.smaller} 0px;

    background-color: ${(props) => {
      return props.theme.backgroundLevel1;
    }};

    div {
      background-color: ${(props) => {
        return props.theme.backgroundLevel1;
      }};
    }
  }
  .metrics {
    grid-area: metrics;
    display: flex;
    flex-direction: column;

    // Needed to avoid dynamically sized charts to expand infinitely on refresh
    // more info here: https://www.w3.org/TR/css3-grid-layout/#min-size-auto
    min-width: 0;
    min-height: 0;
  }
`;

const DashboardPage = () => {
  return (
    <DashboardGrid>
      <div className="header">
        <TimespanSelector />
      </div>
      <SyncedCursorCharts>
        <div className="health">
          <DashboardGlobalHealth />
        </div>
        <div className="inventory">
          <DashboardInventory />
          <DashboardServices />
        </div>
        <div className="network">
          <DashboardCPBandwidthChart
            title="ControlPlane Bandwidth"
            plane="controlPlane"
          ></DashboardCPBandwidthChart>
          <DashboardCPBandwidthChart
            title="WorkloadPlane Bandwidth"
            plane="workloadPlane"
          ></DashboardCPBandwidthChart>
        </div>
        <div className="metrics">
          <DashboardMetrics />
        </div>
      </SyncedCursorCharts>
    </DashboardGrid>
  );
};
export default DashboardPage;
