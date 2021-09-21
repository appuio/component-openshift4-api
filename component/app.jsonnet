local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_api;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('openshift4-api', params.namespace);

{
  'openshift4-api': app,
}
