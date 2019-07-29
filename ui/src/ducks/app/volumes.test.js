import { call, put } from 'redux-saga/effects';
import {
  fetchStorageClass,
  fetchPersistentVolumes,
  setPersistentVolumesAction
} from './volumes';
import * as ApiK8s from '../../services/k8s/api';
import { SET_STORAGECLASS } from './volumes.js';

it('update the storage class', () => {
  // Working case
  const gen = fetchStorageClass();

  expect(gen.next().value).toEqual(call(ApiK8s.getStorageClass));
  const result = {
    body: {
      items: [
        {
          metadata: {
            name: 'standard',
            selfLink: '/apis/storage.k8s.io/v1/storageclasses/standard',
            uid: 'ad65238e-c860-4782-bdda-f8468998086e',
            resourceVersion: '21491',
            creationTimestamp: '2019-07-25T15:52:24Z'
          },
          provisioner: 'kubernetes.io/aws-ebs',
          parameters: {
            type: 'gp2'
          },
          reclaimPolicy: 'Retain',
          mountOptions: ['debug'],
          volumeBindingMode: 'Immediate'
        }
      ]
    }
  };
  expect(gen.next(result).value).toEqual(
    put({ type: SET_STORAGECLASS, payload: result.body.items })
  );

  expect(gen.next().done).toEqual(true);
});

it('does not update the storage class if there is an error', () => {
  const gen = fetchStorageClass();

  expect(gen.next().value).toEqual(call(ApiK8s.getStorageClass));

  const result = {
    error: {}
  };

  expect(gen.next(result).done).toEqual(true);
});

it('update PVs', () => {
  const gen = fetchPersistentVolumes();
  expect(gen.next().value).toEqual(call(ApiK8s.getPersistentVolumes));

  const result = {
    body: {
      items: [
        {
          metadata: {
            name: 'yanjin-test',
            selfLink: '/api/v1/persistentvolumes/yanjin-test',
            uid: '1e949b2e-7e6f-4ba7-8dd8-eddb73d8455b',
            resourceVersion: '26098',
            creationTimestamp: '2019-07-25T16:49:10Z',
            ownerReferences: [
              {
                apiVersion: 'storage.metalk8s.scality.com/v1alpha1',
                kind: 'Volume',
                name: 'yanjin-test',
                uid: '5e417a13-71cd-4b80-81e9-112dff5da750',
                controller: true,
                blockOwnerDeletion: true
              }
            ],
            finalizers: [
              'storage.metalk8s.scality.com/volume-protection',
              'kubernetes.io/pv-protection'
            ]
          },
          spec: {
            capacity: {
              storage: '1Gi'
            },
            local: {
              path: '/tmp/foo'
            },
            accessModes: ['ReadWriteOnce'],
            persistentVolumeReclaimPolicy: 'Retain',
            storageClassName: 'standard',
            volumeMode: 'Filesystem',
            nodeAffinity: {
              required: {
                nodeSelectorTerms: [
                  {
                    matchExpressions: [
                      {
                        key: 'kubernetes.io/hostname',
                        operator: 'In',
                        values: ['metalk8s-bootstrap.novalocal']
                      }
                    ],
                    matchFields: [
                      {
                        key: 'metadata.name',
                        operator: 'In',
                        values: ['metalk8s-bootstrap.novalocal']
                      }
                    ]
                  }
                ]
              }
            }
          },
          status: {
            phase: 'Available'
          }
        }
      ]
    }
  };

  expect(gen.next(result).value).toEqual(
    put(setPersistentVolumesAction(result.body.items))
  );
});

it('should put a empty array if PVs object is not correct', () => {
  const gen = fetchPersistentVolumes();
  expect(gen.next().value).toEqual(call(ApiK8s.getPersistentVolumes));

  const result = { it: 'should not work' };

  expect(gen.next(result).value).toEqual(put(setPersistentVolumesAction([])));
});

it('does not update PV if there is an error', () => {
  const gen = fetchPersistentVolumes();

  expect(gen.next().value).toEqual(call(ApiK8s.getPersistentVolumes));

  const result = {
    error: {}
  };

  expect(gen.next(result).done).toEqual(true);
});
