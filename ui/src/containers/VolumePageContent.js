import React from 'react';
import { useHistory } from 'react-router';
import { allSizeUnitsToBytes } from '../services/utils';
import VolumeListTable from '../components/VolumeListTable';
import VolumeDetailCard from '../components/VolumeDetailCard';
import ActiveAlertsCard from '../components/VolumeActiveAlertsCard';
import MetricGraphCard from '../components/VolumeMetricGraphCard';
import {
  SPARSE_LOOP_DEVICE,
  RAW_BLOCK_DEVICE,
  PORT_NUMBER_PROMETHEUS,
} from '../constants';
import { computeVolumeGlobalStatus } from '../services/NodeVolumesUtils';
import {
  LeftSideInstanceList,
  RightSidePanel,
  NoInstanceSelectedContainer,
  NoInstanceSelected,
  PageContentContainer,
} from '../components/CommonLayoutStyle';
import { intl } from '../translations/IntlGlobalProvider';

// <VolumePageContent> component extracts volume name from URL and holds the volume-specific data.
// The three components in RightSidePanel (<VolumeDetailCard> / <ActiveAlertsCard> / <MetricGraphCard>) are dumb components,
// so that with the implementation of Tabs no re-render should happen during the switch.
const VolumePageContent = (props) => {
  const {
    volumes,
    nodes,
    node,
    volumeListData,
    pVList,
    pods,
    alerts,
    volumeStats,
  } = props;

  const history = useHistory();
  const currentVolumeName = history?.location?.pathname?.split('/').pop();

  const volume = volumes?.find(
    (volume) => volume.metadata.name === currentVolumeName,
  );
  const currentVolume = volumeListData?.find(
    (vol) => vol.name === currentVolumeName,
  );

  const pV = pVList?.find((pv) => pv.metadata.name === currentVolumeName);
  const volumeStatus = computeVolumeGlobalStatus(
    volume?.metadata?.name,
    volume?.status,
  );

  // get the used pod(s)
  const PVCName = pV?.spec?.claimRef?.name;

  // we need to make sure that `PVCName` is exist otherwise may return undefined `persistentVolumeClaim` pod
  const UsedPod =
    PVCName &&
    pods?.find((pod) =>
      pod.volumes.find((volume) => volume.persistentVolumeClaim === PVCName),
    );

  // get the alert
  const alertlist =
    PVCName &&
    alerts?.list?.filter(
      (alert) => alert.labels.persistentvolumeclaim === PVCName,
    );

  // prepare the data for <PerformanceGraphCard>
  const deviceName = volume?.status?.deviceName;
  let instance;

  if (!node.internalIP) {
    // find the node name of this volume
    const nodeName = volume?.spec?.nodeName;
    const currentNode = nodes.find((node) => node.name === nodeName);
    instance = currentNode?.internalIP + PORT_NUMBER_PROMETHEUS;
  } else {
    instance = node?.internalIP + PORT_NUMBER_PROMETHEUS;
  }

  const queryStartingTime = volumeStats?.queryStartingTime;
  const volumeUsed = volumeStats?.volumeUsed?.filter(
    (vU) => vU.metric.persistentvolumeclaim === PVCName,
  );
  const volumeThroughputWrite = volumeStats?.volumeThroughputWrite?.filter(
    (vTW) =>
      vTW.metric.instance === instance && vTW.metric.device === deviceName,
  );
  const volumeThroughputRead = volumeStats?.volumeThroughputRead?.filter(
    (vTR) =>
      vTR.metric.instance === instance && vTR.metric.device === deviceName,
  );
  const volumeLatency = volumeStats?.volumeLatency?.filter(
    (vL) => vL.metric.instance === instance && vL.metric.device === deviceName,
  );
  const volumeIOPSRead = volumeStats?.volumeIOPSRead?.filter(
    (vIOPSR) =>
      vIOPSR.metric.instance === instance &&
      vIOPSR.metric.device === deviceName,
  );
  const volumeIOPSWrite = volumeStats?.volumeIOPSWrite?.filter(
    (vIOPSW) =>
      vIOPSW.metric.instance === instance &&
      vIOPSW.metric.device === deviceName,
  );
  const volumeMetricGraphData = {
    volumeUsed,
    volumeThroughputWrite,
    volumeThroughputRead,
    volumeLatency,
    volumeIOPSRead,
    volumeIOPSWrite,
    queryStartingTime,
  };

  return (
    <PageContentContainer>
      <LeftSideInstanceList>
        <VolumeListTable
          volumeListData={volumeListData}
          nodeName={node?.name}
          volumeName={currentVolumeName}
        ></VolumeListTable>
      </LeftSideInstanceList>

      {currentVolumeName && volume ? (
        <RightSidePanel>
          <VolumeDetailCard
            name={currentVolumeName}
            nodeName={volume?.spec?.nodeName}
            storage={pV?.spec?.capacity?.storage ?? intl.translate('unknown')}
            status={volumeStatus ?? intl.translate('unknown')}
            storageClassName={volume?.spec?.storageClassName}
            creationTimestamp={volume?.metadata?.creationTimestamp}
            volumeType={
              volume?.spec?.rawBlockDevice
                ? RAW_BLOCK_DEVICE
                : SPARSE_LOOP_DEVICE
            }
            usedPodName={UsedPod ? UsedPod?.name : intl.translate('not_used')}
            devicePath={
              volume?.spec?.rawBlockDevice?.devicePath ??
              intl.translate('not_applicable')
            }
            volumeUsagePercentage={currentVolume?.usage}
            volumeUsageBytes={currentVolume?.usageRawData ?? 0}
            storageCapacity={
              volumeListData?.find((vol) => vol.name === currentVolumeName)
                .storageCapacity
            }
            health={
              volumeListData?.find((vol) => vol.name === currentVolumeName)
                .health
            }
            condition={currentVolume.status}
            // the delete button inside the volume detail card should know that which volume is the first one
            volumeListData={volumeListData}
            pVList={pVList}
          ></VolumeDetailCard>
          <ActiveAlertsCard
            alertlist={alertlist}
            PVCName={PVCName}
          ></ActiveAlertsCard>
          <MetricGraphCard
            volumeMetricGraphData={volumeMetricGraphData}
            volumeStorageCapacity={allSizeUnitsToBytes(
              pV?.spec?.capacity?.storage,
            )}
            // the volume condition compute base on the `status` and `bound/unbound`
            volumeCondition={currentVolume.status}
            // Hardcode the port number for prometheus metrics
          ></MetricGraphCard>
        </RightSidePanel>
      ) : (
        <NoInstanceSelectedContainer>
          <NoInstanceSelected>
            {intl.translate('no_volume_selected')}
          </NoInstanceSelected>
        </NoInstanceSelectedContainer>
      )}
    </PageContentContainer>
  );
};

export default VolumePageContent;
