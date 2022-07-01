local cm = import 'lib/cert-manager.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_api;

local nsName = 'syn-monitoring-openshift4-api';

local apiServerMonitor = function(name, selectorTargetLabel)
  prom.ServiceMonitor(name) {
    metadata+: {
      namespace: nsName,
    },
    spec+: {
      endpoints: [
        {
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          interval: '30s',
          metricRelabelings: [
            {
              action: 'drop',
              regex: 'etcd_(debugging|disk|server).*',
              sourceLabels: [
                '__name__',
              ],
            },
            {
              action: 'drop',
              regex: 'apiserver_admission_controller_admission_latencies_seconds_.*',
              sourceLabels: [
                '__name__',
              ],
            },
            {
              action: 'drop',
              regex: 'apiserver_admission_step_admission_latencies_seconds_.*',
              sourceLabels: [
                '__name__',
              ],
            },
            {
              action: 'drop',
              regex: 'apiserver_request_duration_seconds_bucket;(0.15|0.25|0.3|0.35|0.4|0.45|0.6|0.7|0.8|0.9|1.25|1.5|1.75|2.5|3|3.5|4.5|6|7|8|9|15|25|30|50)',
              sourceLabels: [
                '__name__',
                'le',
              ],
            },
          ],
          port: 'https',
          relabelings: [
            {
              action: 'replace',
              replacement: name,
              targetLabel: 'apiserver',
            },
          ],
          scheme: 'https',
          tlsConfig: {
            caFile: '/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt',
            certFile: '/etc/prometheus/secrets/ocp-metric-client-certs-monitoring/tls.crt',
            keyFile: '/etc/prometheus/secrets/ocp-metric-client-certs-monitoring/tls.key',
            serverName: 'api.%s.svc' % name,
          },
        },
      ],
      namespaceSelector: {
        matchNames: [
          name,
        ],
      },
      selector: {
        matchLabels: {
          [selectorTargetLabel]: name,
        },
      },
    },
  };

[
  prom.RegisterNamespace(kube.Namespace(nsName)),
  apiServerMonitor('openshift-apiserver', 'prometheus'),
  apiServerMonitor('openshift-oauth-apiserver', 'app'),
]
