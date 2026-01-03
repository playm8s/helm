import * as kplus from 'cdk8s-plus-33';
import { Construct } from 'constructs';
import { App, Chart, ChartProps } from 'cdk8s';

const outdir: string = '../dist/manifests/operator';
const suffix: string = '-operator.yaml';

const namespace: string = 'pm8s-system';

const image: string = 'ghcr.io/playm8s/operator:latest';

const httpApiPort: number = 9000;

export class Playm8sOperator extends Chart {
  constructor(
    scope: Construct,
    id: string,
    props: ChartProps = {
      disableResourceNameHashes: true,
      namespace: namespace,
    }
  ) {
    super(scope, id, props);

    const operatorRole = new kplus.Role(this, 'operator-role');

    operatorRole.allowReadWrite(kplus.ApiResource.DEPLOYMENTS);
    const serviceAccount = new kplus.ServiceAccount(this, 'operator-service-account');

    const roleBinding = new kplus.RoleBinding(this, 'operator-role-binding', {
      metadata: {
        name: 'pm8s-operator-rolebinding',
        namespace: namespace,
      },
      role: operatorRole,
    });

    roleBinding.addSubjects(serviceAccount);

    const operatorDeployment = new kplus.Deployment(this, 'operator', {
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
              protocol: kplus.Protocol.TCP,
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
      serviceType: kplus.ServiceType.CLUSTER_IP,
    });
  }
}

const app = new App({
  outputFileExtension: suffix,
  outdir: outdir,
});
new Playm8sOperator(app, 'pm8s');
app.synth();
