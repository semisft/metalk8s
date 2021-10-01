import React from 'react';
import styled, { useTheme } from 'styled-components';
import { spacing } from '@scality/core-ui/dist/style/theme';
import DashboardAlerts from './DashboardAlerts';
import SpacedBox from '@scality/core-ui/dist/components/spacedbox/SpacedBox';
import {
  EmphaseText,
  LargerText,
  SmallerText,
} from '@scality/core-ui/dist/components/text/Text.component';
import TooltipComponent from '@scality/core-ui/dist/components/tooltip/Tooltip.component';
import {
  highestAlertToStatus,
  useAlertLibrary,
  useHighestSeverityAlerts,
} from '../containers/AlertProvider';
import { useIntl } from 'react-intl';
import { useStartingTimeStamp } from '../containers/StartTimeProvider';
import LoaderComponent from '@scality/core-ui/dist/components/loader/Loader.component';
import CircleStatus, { StatusIcon } from './CircleStatus';
import GlobalHealthBarComponent from '@scality/core-ui/dist/components/globalhealthbar/GlobalHealthBar.component';
import { useHistoryAlerts } from '../containers/AlertHistoryProvider';

const GlobalHealthContainer = styled.div`
  display: flex;
  align-items: center;
  height: 100%;
  .datacenter {
    flex: 1 0 20%;
  }
  .healthbar {
    flex: 1 0 40%;
  }
  .alerts {
    flex: 1 0 40%;
  }
  & > div {
    display: flex;
    &:not(:first-of-type):before {
      content: '';
      position: relative;
      margin: auto ${spacing.sp32} auto 0;
      width: ${spacing.sp2};
      height: 75px;
      background-color: ${(props) => props.theme.backgroundLevel1};
    }
  }
`;

const DashboardGlobalHealth = () => {
  const intl = useIntl();
  const theme = useTheme();
  const { startingTimeISO, currentTimeISO } = useStartingTimeStamp();
  const alertsLibrary = useAlertLibrary();

  const { alerts, status: historyAlertStatus } = useHistoryAlerts(
    alertsLibrary.getPlatformAlertSelectors(),
  );
  const platformHighestSeverityAlert = useHighestSeverityAlerts(
    alertsLibrary.getPlatformAlertSelectors(),
  );
  const platformStatus = highestAlertToStatus(platformHighestSeverityAlert);

  return (
    <GlobalHealthContainer>
      <div className="datacenter">
        <SpacedBox ml={12} mr={12}>
          <StatusIcon
            status={platformStatus}
            className="fa fa-warehouse fa-2x"
          ></StatusIcon>
        </SpacedBox>

        <LargerText>{intl.formatMessage({ id: 'platform' })}</LargerText>
      </div>
      <div className="healthbar">
        <div style={{ flexDirection: 'column', width: '100%' }}>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <SpacedBox
              style={{ display: 'flex', alignItems: 'center' }}
              mr={20}
            >
              <SpacedBox mr={8}>
                <EmphaseText style={{ letterSpacing: spacing.sp2 }}>
                  Global Health
                </EmphaseText>
              </SpacedBox>

              <TooltipComponent
                placement="bottom"
                overlay={
                  <SmallerText style={{ minWidth: '30rem', display: 'block' }}>
                    {intl
                      .formatMessage({
                        id: 'global_health_explanation',
                      })
                      .split('\n')
                      .map((line, key) => (
                        <SpacedBox key={`globalheathexplanation-${key}`} mb={8}>
                          {line}
                        </SpacedBox>
                      ))}
                  </SmallerText>
                }
              >
                <i
                  className="fas fa-question-circle"
                  style={{ color: theme.buttonSecondary }}
                ></i>
              </TooltipComponent>
            </SpacedBox>
            <EmphaseText>
              <CircleStatus status={platformStatus} />
            </EmphaseText>
            {historyAlertStatus === 'loading' && (
              <SpacedBox ml={8}>
                <LoaderComponent size={'larger'} />
              </SpacedBox>
            )}
          </div>
          <SpacedBox
              mr={20}
            >
          <GlobalHealthBarComponent
            id={'platform_globalhealth'}
            alerts={
              historyAlertStatus === 'error'
                ? [
                    {
                      startsAt: startingTimeISO,
                      endsAt: currentTimeISO,
                      severity: 'unavailable',
                      description:
                        'Failed to load alert history for the selected period',
                    },
                  ]
                : alerts || []
            }
            start={startingTimeISO}
            end={currentTimeISO}
          />
          </SpacedBox>
        </div>
      </div>

      <div className="alerts">
        <DashboardAlerts />
      </div>
    </GlobalHealthContainer>
  );
};

export default DashboardGlobalHealth;
