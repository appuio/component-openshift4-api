// main template for openshift4-api
local cm = import 'lib/cert-manager.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_api;

local apiServerName = 'cluster';
local prefix = 'api-server-' + apiServerName + '-certificate-';

local servingCerts =
  if params.servingCerts == null then
    {}
  else
    params.servingCerts;

local nonNullServingCerts = std.prune([
  if servingCerts[k] != null then k
  for k in std.objectFields(servingCerts)
]);

local rawSecrets = [
  if std.objectHas(servingCerts[k], 'cert') && servingCerts[k].cert != null then
    error 'Cannot use both static and cert-manager generated certificate for "%s"' % k
  else
    kube.Secret(prefix + k) {
      type: 'kubernetes.io/tls',
      metadata+: {
        namespace: 'openshift-config',
      },
    } + com.makeMergeable(servingCerts[k].secret)
  for k in nonNullServingCerts
  if std.objectHas(servingCerts[k], 'secret') && servingCerts[k].secret != null
];

local certs = [
  if std.objectHas(servingCerts[k], 'secret') && servingCerts[k].secret != null then
    error 'Cannot use both static and cert-manager generated certificate for "%s"' % k
  else
    cm.cert(prefix + k) {
      metadata+: {
        namespace: 'openshift-config',
      },
      spec+: {
        secretName: prefix + k,
      } + com.makeMergeable(servingCerts[k].cert),
    }
  for k in nonNullServingCerts
  if std.objectHas(servingCerts[k], 'cert') && servingCerts[k].cert != null
];

local apiServer = {
  apiVersion: 'config.openshift.io/v1',
  kind: 'APIServer',
  metadata: {
    name: 'cluster',
    annotations: std.prune(
      {
        'oauth-apiserver.openshift.io/secure-token-storage': 'true',
        'release.openshift.io/create-only': 'true',
      }
      + com.makeMergeable(params.apiServerAnnotations)
      + {
        // Delay apply of the APIServer resource until secrets and certs are
        // deployed and healthy
        'argocd.argoproj.io/sync-wave': '10',
      }
    ),
  },
  spec: com.makeMergeable(params.apiServerSpec) + {
    [if std.length(nonNullServingCerts) > 0 then 'servingCerts']: {
      namedCertificates: [
        {
          names: servingCerts[k].names,
          servingCertificate: {
            name: prefix + k,
          },
        }
        for k in nonNullServingCerts
      ],
    },
  },
};


// Define outputs below
{
  [if std.length(certs) > 0 then '00_certs']: certs,
  [if std.length(rawSecrets) > 0 then '00_secrets']: rawSecrets,
  '10_apiserver': apiServer,
  [if params.monitoring.enabled then '20_monitoring']: (import 'monitoring.libsonnet'),
}
