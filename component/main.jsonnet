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

local rawSecrets = [
  if std.objectHas(params.servingCerts[k], 'cert') && params.servingCerts[k].cert != null then
    error 'Cannot use both static and cert-manager generated certificate for "%s"' % k
  else
    kube.Secret(prefix + k) {
      type: 'kubernetes.io/tls',
      metadata+: {
        namespace: 'openshift-config',
      },
    } + com.makeMergeable(params.servingCerts[k].secret)
  for k in std.objectFields(params.servingCerts)
  if std.objectHas(params.servingCerts[k], 'secret') && params.servingCerts[k].secret != null
];

local certs = [
  if std.objectHas(params.servingCerts[k], 'secret') && params.servingCerts[k].secret != null then
    error 'Cannot use both static and cert-manager generated certificate for "%s"' % k
  else
    cm.cert(prefix + k) {
      metadata+: {
        namespace: 'openshift-config',
      },
      spec+: {
        secretName: prefix + k,
      } + com.makeMergeable(params.servingCerts[k].cert),
    }
  for k in std.objectFields(params.servingCerts)
  if std.objectHas(params.servingCerts[k], 'cert') && params.servingCerts[k].cert != null
];

local apiServer = {
  apiVersion: 'config.openshift.io/v1',
  kind: 'APIServer',
  metadata: {
    name: 'cluster',
    annotations: {
      'include.release.openshift.io/self-managed-high-availability': 'true',
      'include.release.openshift.io/single-node-developer': 'true',
      'oauth-apiserver.openshift.io/secure-token-storage': 'true',
      'release.openshift.io/create-only': 'true',
    },
  },
  spec: {
    audit: params.audit,
    servingCerts: [
      {
        names: params.servingCerts[k].names,
        servingCertificate: {
          name: prefix + k,
        },
      }
      for k in std.objectFields(params.servingCerts)
    ],
  },
};


// Define outputs below
{
  '00_certs': certs,
  '00_secrets': rawSecrets,
  '10_apiserver': apiServer,
}
