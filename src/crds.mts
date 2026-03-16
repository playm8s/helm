import { Construct } from 'constructs';
import * as cdk8splus from 'cdk8s-plus-33';
import * as cdk8s from 'cdk8s';

const outdir: string = '../dist/manifests/crds';
const suffix: string = '-crds.yaml';

const namespace: string = 'pm8s-system';

const image: string = 'ghcr.io/playm8s/crds:latest';

export class Playm8sCrdJob extends cdk8s.Chart {
  constructor(
    scope: Construct,
    id: string,
    props: cdk8s.ChartProps = {
      disableResourceNameHashes: true,
      namespace: namespace,
    }
  ) {
    super(scope, id, props);

    const crdJobRole = new cdk8splus.Role(this, 'crd-job-role');

    crdJobRole.allowReadWrite(
      cdk8splus.ApiResource.CUSTOM_RESOURCE_DEFINITIONS
    );
    const serviceAccount = new cdk8splus.ServiceAccount(
      this,
      'crd-job-service-account'
    );

    const roleBinding = new cdk8splus.RoleBinding(
      this,
      'crd-job-role-binding',
      {
        metadata: {
          name: 'pm8s-crd-job-rolebinding',
          namespace: namespace,
        },
        role: crdJobRole,
      }
    );

    roleBinding.addSubjects(serviceAccount);

    new cdk8splus.Job(this, 'crd-job', {
      metadata: {
        labels: {
          'pm8s.io/crds': 'true',
        },
      },
      automountServiceAccountToken: true,
      serviceAccount: serviceAccount,
      select: true,
      containers: [
        {
          image: image,
          envVariables: {
            KUBE_IN_CLUSTER_CONFIG: cdk8splus.EnvValue.fromValue('true'),
          },
        },
      ],
      ttlAfterFinished: cdk8s.Duration.seconds(600),
    });
  }
}

const app = new cdk8s.App({
  outputFileExtension: suffix,
  outdir: outdir,
});
new Playm8sCrdJob(app, 'pm8s');
app.synth();
