# ECSForgate �������X���

## ́j-z�

### ���Ư��-

1. **ޤ����ӹ���Ư��n�(**
   - API_�n�h������ƣ���Y�_�
   - e�j_��5k��W�YOY�_�
   - �������Thn��W_�z��������kY�_�

2. **����ȥ��API��ӹ**
   - API���ݤ�Ȓ������������kP�
   - VPC Endpoint�(W_���j��
   - FISC�h�V��k��Y�_�n-

3. **AWS��ӹx�**
   - ECS Fargate����칳��ʟL��hWf������
   - RDS PostgreSQL��󶯷���ht'��
   - ALB + API GatewayAPI��գï�h����ƣ
   - CloudWatch + X-Rayq�hc�����

### ������ï���-

1. **-ɭ����nr**
   - Socommon-log-monitoring-backup.mdhWf1dn-�g�
   - ��L�k�_�_��n3dnɭ����kr
     - ���-�log-design.md	
     - �-�monitoring-design.md	
     - �ï���-�backup-design.md	
   - �!ա�뒋Wf���g��k

2. **���ńz��**
   - � JSON��թ����n�("h�n��
   - ��Thnij�����-��z��goDEBUG,j��goINFO
   - CloudWatch Logs Insightsk������M��
   - ,j��nS3w����֒����� i	

3. **�-ńz��**
   - �j��꯹��S6
   - X-Rayc�����ne��������o��Thk i	
   - �%�k�X_����������SMS	
   - e�kAmazon Connectk���q�ne

4. **�ï���&eńz��**
   - AWS Backupk��q�
   - d�ï���&e�!1!!	
   - ��Thn�� i���n	
   - ,j��n���������ï��ן�
   - �Cƹ�n����k����'��

## ����hɭ����

1. **AWS-ٹ���ƣ�**
   - [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
   - [AWS ��ӹThn-ѿ��](https://aws.amazon.com/architecture/reference-architecture-diagrams/)

2. **FISC�h�V��**
   - э_�I����������n�h�V�����

3. **Spring Boot AWS#:ٹ���ƣ�**
   - [AWS gn Spring Boot �������n����](https://aws.amazon.com/jp/getting-started/hands-on/deploy-spring-boot-app-to-aws/)

## ������ƣ�et

*�B�go~`��է��kecfDjD_�2jW*

## ���1

### �z��
- AWS �����: ap-northeast-1 (q�)
- VPC CIDR: 10.0.0.0/16
- RDS: db.t3.small
- ECS Fargate: 0.5vCPU, 1GB ���

### ����󰰃
- AWS �����: ap-northeast-1 (q�)
- VPC CIDR: 10.1.0.0/16
- RDS: db.t3.small
- ECS Fargate: 0.5vCPU, 1GB ���

### ,j��
- AWS �����: ap-northeast-1 (q�) + DR: ap-northeast-3 ('*)
- VPC CIDR: 10.2.0.0/16
- RDS: db.m5.large (���AZ)
- ECS Fargate: 1vCPU, 2GB ���
