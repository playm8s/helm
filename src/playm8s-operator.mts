import { Construct } from 'constructs';
import * as cdk8splus from 'cdk8s-plus-33';
import * as cdk8s from 'cdk8s';

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

    const operatorRole = new cdk8splus.Role(this, 'operator-role');

    operatorRole.allowReadWrite(cdk8splus.ApiResource.DEPLOYMENTS);
    const serviceAccount = new cdk8splus.ServiceAccount(
      this,
      'operator-service-account'
    );

    const roleBinding = new cdk8splus.RoleBinding(
      this,
      'operator-role-binding',
      {
        metadata: {
          name: 'pm8s-operator-rolebinding',
          namespace: namespace,
        },
        role: operatorRole,
      }
    );

    roleBinding.addSubjects(serviceAccount);

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
