from parameterized import parameterized

from salt.exceptions import CommandExecutionError

from salttesting.mixins import LoaderModuleMockMixin
from salttesting.unit import TestCase
from salttesting.mock import MagicMock, patch

import metalk8s_network


class Metalk8sNetworkTestCase(TestCase, LoaderModuleMockMixin):
    """
    TestCase for `metalk8s_network` module
    """
    loader_module = metalk8s_network
    loader_module_globals = {
        "__pillar__": {
            "networks": {
                "service": "10.0.0.0/8"
            }
        }
    }

    def test_virtual(self):
        """
        Tests the return of `__virtual__` function
        """
        self.assertEqual(metalk8s_network.__virtual__(), 'metalk8s_network')

    def test_get_kubernetes_service_ip_success(self):
        """
        Tests the return of `get_kubernetes_service_ip` function, success
        """
        self.assertEqual(
            metalk8s_network.get_kubernetes_service_ip(),
            "10.0.0.1"
        )

    @parameterized.expand([
        (None, 'Pillar key "networks:service" must be set.'),
        (
            '10.0.0.0/32',
            'Could not obtain an IP in the network range 10.0.0.0/32'
        )
    ])
    def test_get_kubernetes_service_ip_raise(self, service_ip, error_msg):
        """
        Tests the return of `get_kubernetes_service_ip` function, when raising
        """
        with patch.dict(
                metalk8s_network.__pillar__,
                {'networks': {'service': service_ip}}):
            self.assertRaisesRegexp(
                CommandExecutionError,
                error_msg,
                metalk8s_network.get_kubernetes_service_ip
            )

    def test_get_cluster_dns_ip_success(self):
        """
        Tests the return of `get_cluster_dns_ip` function, success
        """
        self.assertEqual(metalk8s_network.get_cluster_dns_ip(), "10.0.0.10")

    @parameterized.expand([
        (None, 'Pillar key "networks:service" must be set.'),
        (
            '10.0.0.0/31',
            'Could not obtain an IP in the network range 10.0.0.0/31'
        )
    ])
    def test_get_cluster_dns_ip_raise(self, service_ip, error_msg):
        """
        Tests the return of `get_cluster_dns_ip` function, when raising
        """
        with patch.dict(
                metalk8s_network.__pillar__,
                {'networks': {'service': service_ip}}):
            self.assertRaisesRegexp(
                CommandExecutionError,
                error_msg,
                metalk8s_network.get_cluster_dns_ip
            )

    @parameterized.expand([
        # 1 CIDR, 2 IP, take the first one
        (['10.200.0.0/16'], ['10.200.0.1', '10.200.0.42'], '10.200.0.1'),
        # 1 CIDR, 2 IP, current_ip set to the second one, take the second one
        (['10.200.0.0/16'], ['10.200.0.1', '10.200.0.42'], '10.200.0.42', '10.200.0.42'),
        # 1 CIDR, no IP, errors
        (['10.200.0.0/16'], [], 'Unable to find an IP on this host in one of this cidr: 10.200.0.0/16', None, True),
        # 2 CIDR, multiple IPs, take the first one of first CIDR
        (['10.200.0.0/16', '10.100.0.0/16'], {'10.200.0.0/16': ['10.200.0.1', '10.200.0.42'], '10.100.0.0/16': ['10.100.0.12', '10.100.0.52']}, '10.200.0.1'),
        # 2 CIDR, multiple IPs, with current_ip present
        (['10.200.0.0/16', '10.100.0.0/16'], {'10.200.0.0/16': ['10.200.0.1', '10.200.0.42'], '10.100.0.0/16': ['10.100.0.12', '10.100.0.52']}, '10.100.0.52', '10.100.0.52'),
        # 2 CIDR, multiple IPs, with current_ip absent
        (['10.200.0.0/16', '10.100.0.0/16'], {'10.200.0.0/16': ['10.200.0.1', '10.200.0.42'], '10.100.0.0/16': ['10.100.0.12', '10.100.0.52']}, '10.200.0.1', '10.100.0.87'),
        # 2 CIDR, first CIDR no IP
        (['10.200.0.0/16', '10.100.0.0/16'], {'10.100.0.0/16': ['10.100.0.12', '10.100.0.52']}, '10.100.0.12'),
        # 2 CIDR, no IP, with current_ip, errors
        (['10.200.0.0/16', '10.100.0.0/16'], [], 'Unable to find an IP on this host in one of this cidr: 10.200.0.0/16, 10.100.0.0/16', '10.200.0.1', True),
    ])
    def test_get_ip_from_cidrs(self, cidrs, ip_addrs, result,
                               current_ip=None, raises=False):
        """
        Tests the return of `get_ip_from_cidrs` function
        """
        def _get_ip_addrs(cidr):
            if isinstance(ip_addrs, dict):
                return ip_addrs.get(cidr)
            return ip_addrs

        salt_dict = {
            'network.ip_addrs': MagicMock(side_effect=_get_ip_addrs)
        }

        with patch.dict(metalk8s_network.__salt__, salt_dict):
            if raises:
                self.assertRaisesRegexp(
                    CommandExecutionError,
                    result,
                    metalk8s_network.get_ip_from_cidrs,
                    cidrs=cidrs, current_ip=current_ip
                )
            else:
                self.assertEqual(
                    result,
                    metalk8s_network.get_ip_from_cidrs(
                        cidrs=cidrs, current_ip=current_ip
                    )
                )
