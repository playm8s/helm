import { Construct } from 'constructs';
import * as cdk8splus from 'cdk8s-plus-33';
import * as cdk8s from 'cdk8s';

import { pm8s } from '@playm8s/crds';

const outdir: string = '../dist/manifests/operator';
const suffix: string = '-operator.yaml';

const namespace: string = 'pm8s-system';

const image: string = 'ghcr.io/playm8s/operator:latest';

const httpApiPort: number = 9000;

export class Playm8sOperator extends cdk8s.Chart {
  constructor(
    scope: Construct,
    id: string,
    props: cdk8s.ChartProps = {
      disableResourceNameHashes: true,
      namespace: namespace,
    }
  ) {
    super(scope, id, props);

    const operatorRole = new cdk8splus.Role(this, 'operator-role',
      {
        metadata: {
          name: 'pm8s-operator-role',
          namespace: namespace,
          labels: {
            'pm8s.io/operator': 'true',
          },
        },
      }
    );

    const operatorClusterRole = new cdk8splus.ClusterRole(this, 'operator-cluster-role',
      {
        metadata: {
          name: 'pm8s-operator-cluster-role',
          labels: {
            'pm8s.io/operator': 'true',
          },
        },
      }
    )

    operatorRole.allowReadWrite(
      cdk8splus.ApiResource.CONFIG_MAPS,
      cdk8splus.ApiResource.CRON_JOBS,
      cdk8splus.ApiResource.CUSTOM_RESOURCE_DEFINITIONS,
      cdk8splus.ApiResource.DAEMON_SETS,
      cdk8splus.ApiResource.DEPLOYMENTS,
      cdk8splus.ApiResource.JOBS,
      cdk8splus.ApiResource.LEASES,
      cdk8splus.ApiResource.PERSISTENT_VOLUME_CLAIMS,
      cdk8splus.ApiResource.PODS,
      cdk8splus.ApiResource.REPLICA_SETS,
      cdk8splus.ApiResource.SECRETS,
      cdk8splus.ApiResource.SERVICES,
      cdk8splus.ApiResource.STATEFUL_SETS,
      cdk8splus.ApiResource.INGRESSES,
      new pm8s.Gameserver.ApiResource,
      new pm8s.GameserverLayer.ApiResource,
    );

    operatorRole.allowWatch(
      cdk8splus.ApiResource.CONFIG_MAPS,
      cdk8splus.ApiResource.CRON_JOBS,
      cdk8splus.ApiResource.CUSTOM_RESOURCE_DEFINITIONS,
      cdk8splus.ApiResource.DAEMON_SETS,
      cdk8splus.ApiResource.DEPLOYMENTS,
      cdk8splus.ApiResource.JOBS,
      cdk8splus.ApiResource.LEASES,
      cdk8splus.ApiResource.PERSISTENT_VOLUME_CLAIMS,
      cdk8splus.ApiResource.PODS,
      cdk8splus.ApiResource.REPLICA_SETS,
      cdk8splus.ApiResource.SECRETS,
      cdk8splus.ApiResource.SERVICES,
      cdk8splus.ApiResource.STATEFUL_SETS,
      cdk8splus.ApiResource.INGRESSES,
      new pm8s.Gameserver.ApiResource,
      new pm8s.GameserverLayer.ApiResource,
    );

    operatorClusterRole.allowReadWrite(
      cdk8splus.ApiResource.CONFIG_MAPS,
      cdk8splus.ApiResource.CRON_JOBS,
      cdk8splus.ApiResource.CUSTOM_RESOURCE_DEFINITIONS,
      cdk8splus.ApiResource.DAEMON_SETS,
      cdk8splus.ApiResource.DEPLOYMENTS,
      cdk8splus.ApiResource.JOBS,
      cdk8splus.ApiResource.LEASES,
      cdk8splus.ApiResource.PERSISTENT_VOLUME_CLAIMS,
      cdk8splus.ApiResource.PODS,
      cdk8splus.ApiResource.REPLICA_SETS,
      cdk8splus.ApiResource.SECRETS,
      cdk8splus.ApiResource.SERVICES,
      cdk8splus.ApiResource.STATEFUL_SETS,
      cdk8splus.ApiResource.INGRESSES,
      new pm8s.Gameserver.ApiResource,
      new pm8s.GameserverLayer.ApiResource,
    );

    operatorClusterRole.allowWatch(
      cdk8splus.ApiResource.CONFIG_MAPS,
      cdk8splus.ApiResource.CRON_JOBS,
      cdk8splus.ApiResource.CUSTOM_RESOURCE_DEFINITIONS,
      cdk8splus.ApiResource.DAEMON_SETS,
      cdk8splus.ApiResource.DEPLOYMENTS,
      cdk8splus.ApiResource.JOBS,
      cdk8splus.ApiResource.LEASES,
      cdk8splus.ApiResource.PERSISTENT_VOLUME_CLAIMS,
      cdk8splus.ApiResource.PODS,
      cdk8splus.ApiResource.REPLICA_SETS,
      cdk8splus.ApiResource.SECRETS,
      cdk8splus.ApiResource.SERVICES,
      cdk8splus.ApiResource.STATEFUL_SETS,
      cdk8splus.ApiResource.INGRESSES,
      new pm8s.Gameserver.ApiResource,
      new pm8s.GameserverLayer.ApiResource,
    );

    operatorRole.allowRead(
      cdk8splus.ApiResource.INGRESS_CLASSES,
      cdk8splus.ApiResource.NAMESPACES,
      cdk8splus.ApiResource.NODES,
      cdk8splus.ApiResource.VOLUME_ATTACHMENTS,
    );

    const serviceAccount = new cdk8splus.ServiceAccount(
      this,
      'operator-service-account',
      {
        metadata: {
          name: 'pm8s-operator-service-account',
          namespace: namespace,
          labels: {
            'pm8s.io/operator': 'true',
          },
        },
      }
    );

    const roleBinding = new cdk8splus.RoleBinding(
      this,
      'operator-role-binding',
      {
        metadata: {
          name: 'pm8s-operator-role-binding',
          namespace: namespace,
          labels: {
            'pm8s.io/operator': 'true',
          },
        },
        role: operatorRole,
      }
    );

    roleBinding.addSubjects(serviceAccount);

    const clusterRoleBinding = new cdk8splus.ClusterRoleBinding(
      this,
      'operator-cluster-role-binding',
      {
        metadata: {
          name: 'pm8s-operator-cluster-role-binding',
          labels: {
            'pm8s.io/operator': 'true',
          },
        },
        role: operatorClusterRole,
      }
    )

    clusterRoleBinding.addSubjects(serviceAccount);

    const operatorDeployment = new cdk8splus.Deployment(this, 'operator', {
      metadata: {
        labels: {
          'pm8s.io/operator': 'true',
        },
      },
      automountServiceAccountToken: true,
      serviceAccount: serviceAccount,
      select: true,
      containers: [
        {
          image: image,
          ports: [
            {
              name: 'http',
              protocol: cdk8splus.Protocol.TCP,
              number: httpApiPort,
            },
          ],
          envVariables: {
            KUBE_IN_CLUSTER_CONFIG: cdk8splus.EnvValue.fromValue('true'),
            WATCH_OTHER_NAMESPACES: cdk8splus.EnvValue.fromValue('false'),
            HTTP_API_PORT: cdk8splus.EnvValue.fromValue(httpApiPort.toString()),
            NAMESPACE: cdk8splus.EnvValue.fromFieldRef(cdk8splus.EnvFieldPaths.POD_NAMESPACE),
          },
        },
      ],
      replicas: 1,
    });

    operatorDeployment.exposeViaService({
      ports: [
        {
          port: httpApiPort,
          targetPort: httpApiPort,
        },
      ],
      serviceType: cdk8splus.ServiceType.CLUSTER_IP,
    });
  }
}

const app = new cdk8s.App({
  outputFileExtension: suffix,
  outdir: outdir,
});
new Playm8sOperator(app, 'pm8s');
app.synth();
