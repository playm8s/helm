import * as kplus from 'cdk8s-plus-33';
import { Construct } from 'constructs';
import { App, Chart, ChartProps } from 'cdk8s';

export class Playm8sOperator extends Chart {
  constructor(
    scope: Construct,
    id: string,
    props: ChartProps = {
      disableResourceNameHashes: true,
      namespace: 'pm8s-system',
    }
  ) {
    super(scope, id, props);

    const operatorDeployment = new kplus.Deployment(this, 'operator', {
      metadata: {
        labels: {
          'pm8s.io/operator': 'true',
        },
      },
      automountServiceAccountToken: true,
      select: true,
      containers: [
        {
          image: 'ghcr.io/playm8s/operator:latest',
          ports: [
            {
              name: 'http',
              protocol: kplus.Protocol.TCP,
              number: 9000,
            },
          ],
        },
      ],
      replicas: 1,
    });

    operatorDeployment.exposeViaService({
      ports: [
        {
          port: 9000,
          targetPort: 9000,
        },
      ],
      serviceType: kplus.ServiceType.CLUSTER_IP,
    });

    const operatorRole = new kplus.Role(this, 'operator-role');

    operatorRole.allowReadWrite(kplus.ApiResource.DEPLOYMENTS);
    const serviceAccount = new kplus.ServiceAccount(this, 'operator-service-account');

    operatorRole.bind(serviceAccount);
  }
}

const app = new App({
  outputFileExtension: '-operator.yaml',
  outdir: '../dist/manifests/operator',
});
new Playm8sOperator(app, 'pm8s');
app.synth();
